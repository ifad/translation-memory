require 'active_record'
require './shared'

module Pontoon
  def self.connect!
    pg_env = %w( PGUSER PGHOST PGDATABASE PGPASSWORD )

    missing = pg_env.select {|k| ENV[k].blank? }
    if missing.present?
      raise "Please set #{missing.join(' and ')} in the environment"
    end

    ActiveRecord::Base.logger = Logger.new($stderr)
    ActiveRecord::Base.logger.level = :info

    cheer "Connecting to #{ENV['PGHOST']}"

    ActiveRecord::Base.establish_connection(adapter: 'postgresql')
  end

  def self.import!(translations, project_name)
    project = Project.lookup(project_name)
    raise "Project not found: #{project_name}" unless project

    configured_locales = project.locales.map(&:code)

    imported = 0
    translations.sort! {|a,b| a.updated_at <=> b.updated_at }

    translations.each do |translation|
      if configured_locales.include?(translation.language_code)

        if import_translation!(project, translation)
          imported += 1
        end

      else
        bark "Skipping #{translation.source_excerpt}: #{translation.language_code} not in project configured locales"
      end
    end

    cheer "Imported #{imported} out of #{translations.size}!"
  end

  def self.bark(woof)
    ActiveRecord::Base.logger.info("\e[1;31m#{woof}\e[0;0m")
  end

  def self.cheer(woof)
    ActiveRecord::Base.logger.info("\e[1;32m#{woof}\e[0;0m")
  end

  def self.import_translation!(project, translation)
    ret = false

    ActiveRecord::Base.transaction do

      entities = Entity.
        by_project(project).
        by_string(translation.source).to_a

      if entities.blank?
        bark "Skipping #{translation.language_code} - #{translation.source_excerpt}: not found"
        return
      end

      entities.each do |entity|
        pontoon_translation = create_translation!(project, translation, entity)
        if pontoon_translation
          create_memory!(pontoon_translation, project, translation, entity)
          ret = true

          cheer "Imported #{translation.language_code} - #{translation.source_excerpt}"
        end
      end

    end

    return ret
  end

  def self.create_translation!(project, translation, entity)
    record = entity.translations.
      by_locale(translation.language_code).
      find_or_initialize_by({})

    if record.persisted?
      bark "Skipping #{entity.key}: already translated to #{translation.language_code}"
      return
    end

    record.date = translation.created_at
    record.approved = true
    record.approved_date = translation.updated_at
    record.fuzzy = false
    record.extra = '{}'
    record.user = User.lookup_or_default(translation.user)
    record.entity_document = [entity.key, translation.target, nil, nil].join(' ')
    record.string = translation.target
    record.rejected = false
    record.save!

    return record
  end

  def self.create_memory!(pontoon_translation, project, translation, entity)
    memory = Memory.new

    memory.source = translation.source
    memory.target = translation.target

    memory.entity = entity
    memory.locale = pontoon_translation.locale
    memory.translation = pontoon_translation
    memory.project = project
    memory.save!

    return memory
  end

  class Project < ActiveRecord::Base
    self.table_name = 'base_project'

    has_many :resources, inverse_of: :project
    has_many :memories,  inverse_of: :project

    has_many :project_locales
    has_many :locales, through: :project_locales

    belongs_to :latest_translation, class_name: 'Translation'

    def self.lookup(name)
      where(name: name).first
    end
  end

  class Locale < ActiveRecord::Base
    self.table_name = 'base_locale'

    has_many :translations, inverse_of: :locale
    has_many :memories,     inverse_of: :locale
    has_many :translated_resources, inverse_of: :locale

    belongs_to :latest_translation, class_name: 'Translation'

    def self.lookup(code)
      code = code.sub(/-\w+$/, '') # Remove country specifier
      where('lower(code) = ?', code.downcase).first
    end
  end

  class ProjectLocale < ActiveRecord::Base
    self.table_name = 'base_projectlocale'

    belongs_to :project
    belongs_to :locale

    belongs_to :latest_translation, class_name: 'Translation'
  end

  class Resource < ActiveRecord::Base
    self.table_name = 'base_resource'

    belongs_to :project, inverse_of: :resources

    has_many :entities, inverse_of: :resource
    has_many :translated_resources, inverse_of: :resource
  end

  class TranslatedResource < ActiveRecord::Base
    self.table_name = 'base_translatedresource'

    belongs_to :locale, inverse_of: :translated_resources
    belongs_to :resource, inverse_of: :translated_resources

    belongs_to :latest_translation, class_name: 'Translation'
  end

  class Entity < ActiveRecord::Base
    self.table_name = 'base_entity'

    belongs_to :resource, inverse_of: :entities

    has_many :translations, inverse_of: :entity
    has_many :memories,     inverse_of: :entity

    scope :by_project, ->(project) {
      where(resource_id: Resource.where(project_id: project))
    }

    scope :by_string, ->(string) {
      where('lower(trim(string)) = lower(trim(?))', string)
    }
  end

  class Translation < ActiveRecord::Base
    self.table_name = 'base_translation'

    belongs_to :entity, inverse_of: :translations
    belongs_to :locale, inverse_of: :translations
    belongs_to :user,   inverse_of: :translations

    belongs_to :approved_user_id,   class_name: 'User'
    belongs_to :unapproved_user_id, class_name: 'User'
    belongs_to :rejected_user_id,   class_name: 'User'
    belongs_to :unrejected_user_id, class_name: 'User'

    has_many :memories, inverse_of: :translation

    scope :approved, -> { where(approved: true) }

    scope :by_locale, ->(code) {
      where(locale_id: Locale.lookup(code))
    }

    after_create :update_latest_translation_ids
    after_create :update_translation_counters

    def resource
      self.entity.resource
    end

    def project
      self.resource.project
    end

    def project_locale
      self.project.project_locales.
        where(locale: self.locale).first!
    end

    def translated_resources
      self.resource.translated_resources.
        where(locale: self.locale).first!
    end

    private
      def update_latest_translation_ids
        [ self.translated_resources,
          self.project_locale,
          self.locale,
          self.project,
        ].each do |object|
          object.update_column(:latest_translation_id, self.id)
        end
      end

      def update_translation_counters
        [ self.project_locale,
          self.locale,
          self.project,
        ].each do |object|
          object.increment!(:approved_strings, 1)
        end
      end
  end

  class Memory < ActiveRecord::Base
    self.table_name = 'base_translationmemoryentry'

    belongs_to :entity,      inverse_of: :memories
    belongs_to :locale,      inverse_of: :memories
    belongs_to :translation, inverse_of: :memories
    belongs_to :project,     inverse_of: :memories
  end

  class User < ActiveRecord::Base
    self.table_name = 'auth_user'

    has_many :translations, inverse_of: :user

    def self.lookup(uid)
      where(username: uid).first
    end

    def self.default
      lookup('v.chiartano')
    end

    def self.lookup_or_default(uid)
      lookup(uid) || default
    end
  end
end
