require 'active_record'
require 'csv'
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

  def self.timed_file_name(prefix, ext)
    "#{prefix}-#{Time.now.strftime('%Y-%m-%d.%H%M%S')}.csv"
  end

  def self.import!(translations, project_slug)
    log_name = timed_file_name('IMPORT', 'csv')
    openlog(log_name)

    project = Project.lookup(project_slug)
    unless project
      raise "Project with slug `#{project_slug}' was not found"
    end

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
    cheer "Written log to #{log_name}"

    closelog
  end

  def self.openlog(name)
    @log = CSV.open(name, 'w')
    @log.sync = true
    @log << ['Result', 'Language', 'LS Label', 'Pontoon Label', 'Pontoon ID', 'Translation']
  end

  def self.log(what, ls_xlation, pontoon_entity, pontoon_xlation)
    raise 'Log not open' unless @log

    @log << [
      what,
      ls_xlation.language_code,
      ls_xlation.source,
      pontoon_entity.try(:string),
      pontoon_entity.try(:id),
      pontoon_xlation.try(:string)
    ]
  end

  def self.closelog
    raise 'Log not open' unless @log

    @log.close
    @log = nil
  end

  def self.bark(woof)
    ActiveRecord::Base.logger.info("\e[1;31m#{woof}\e[0;0m")
  end

  def self.hmmm(woof)
    ActiveRecord::Base.logger.info("\e[1;33m#{woof}\e[0;0m")
  end

  def self.cheer(woof)
    ActiveRecord::Base.logger.info("\e[1;32m#{woof}\e[0;0m")
  end

  def self.import_translation!(project, translation)
    ActiveRecord::Base.transaction do

      entities = if translation.resource && translation.key
        project.entities.by_resource_and_key(translation.resource, translation.key)
      else
        project.entities.by_string(translation.source)
      end

      entities = entities.to_a

      if entities.blank?
        log 'NOTFOUND', translation, nil, nil

        bark "Skipping #{translation.language_code} - #{translation.source_excerpt}: not found"
        return false
      end

      entities.each do |entity|
        pontoon_translation = create_translation!(project, translation, entity)

        if pontoon_translation
          log 'IMPORT', translation, entity, pontoon_translation

          cheer "Imported #{translation.language_code} - #{translation.source_excerpt}"
        else
          log 'SKIPPED', translation, entity, nil

          hmmm "Skipping #{entity.key}: already translated to #{translation.language_code}"
        end
      end

    end

    return true
  end

  def self.export_missing_translations_for(project, locale, mode = :single)
    exporter = ['export', mode, 'entities'].join('_')
    raise "Invalid mode: #{mode}" unless respond_to?(exporter)

    entities = project.entities.includes(:resource).missing_translations_on(locale).to_a

    output = timed_file_name("MISSING-#{locale}-#{project.slug}", 'csv')
    output = CSV.open(output, 'w')

    self.public_send(exporter, entities, output)

    output.close
  end

  def self.export_single_entities(entities, output)
    output << [ 'Key', 'String', 'Translation', 'Comment', 'Resource', 'Author', 'Date/Time' ]

    entities.each do |entity|
      output << [
        entity.key,
        entity.string,
        '', # Translation
        entity.comment,
        entity.resource.path,
        '', # Author
        '', # Date/Time
      ]
    end

    cheer "Exported #{entities.count} entities to #{output.path}"
  end

  def self.export_condensed_entities(entities, output)
    output << [ 'Key', 'String', 'Translation', 'Comment', 'Author', 'Date/Time' ]

    entities_by_string = entities.inject({}) do |h, entity|
      string = entity.string.downcase.strip

      h[string] ||= []
      h[string].push(entity)

      h
    end

    entities_by_string.each do |string, es|
      keys = es.map {|e| [e.resource.path, e.key].join(':') }.join(';')

      output << [
        keys,
        es.first.string, # As it's more or less the same...
        '', # Translation
        es.map(&:comment).join("\n\n"),
        '', # Author
        '', # Date/Time
      ]
    end

    gain = ((1 - entities_by_string.count.to_f/entities.count.to_f) * 100).round(2)
    cheer "Exported #{entities.count} entities to #{output.path} as #{entities_by_string.count} rows (#{gain}% gain)"
  end

  def self.export_translations(translations, project, locale)
    output = timed_file_name("TRANSLATIONS-#{locale}-#{project.slug}", 'csv')
    output = CSV.open(output, 'w')

    output << [ 'Resource', 'Key', 'String', 'Translation', 'Comment', 'Author', 'Date/Time' ]

    translations.each do |translation|
      output << [
        translation.resource.path,
        translation.entity.key,
        translation.entity.string,
        translation.string,
        translation.entity.comment,
        translation.user.username,
        translation.date.localtime,
      ]
    end

    output.close

    cheer "Exported #{translations.count} to #{output.path}"
  end

  def self.create_translation!(project, translation, entity)
    record = entity.translations.
      by_locale(translation.language_code).
      find_or_initialize_by({})

    return if record.persisted?

    record.date = translation.created_at
    record.approved = false
    #record.approved_date = translation.updated_at
    record.fuzzy = false
    record.extra = '{}'
    record.user = User.lookup_or_default(translation.user)
    record.entity_document = [entity.key, translation.target, nil, nil].join(' ')
    record.string = translation.target
    record.rejected = false
    record.verbatim = false
    record.save!

    return record
  end

  class Project < ActiveRecord::Base
    self.table_name = 'base_project'

    has_many :resources,       inverse_of: :project
    has_many :memories,        inverse_of: :project
    has_many :project_locales, inverse_of: :project

    has_many :entities,     through: :resources
    has_many :translations, through: :entities
    has_many :locales,      through: :project_locales

    belongs_to :latest_translation, class_name: 'Translation'

    def self.lookup(slug)
      where(slug: slug).first
    end
  end

  class Locale < ActiveRecord::Base
    self.table_name = 'base_locale'

    has_many :translations, inverse_of: :locale
    has_many :memories,     inverse_of: :locale
    has_many :translated_resources, inverse_of: :locale
    has_many :project_locales, inverse_of: :locale

    belongs_to :latest_translation, class_name: 'Translation'

    def to_s
      code
    end

    def self.lookup(code)
      return code if code.is_a?(self)

      code = code.sub(/-\w+$/, '') # Remove country specifier
      where('lower(code) = ?', code.downcase).first
    end
  end

  class ProjectLocale < ActiveRecord::Base
    self.table_name = 'base_projectlocale'

    belongs_to :project, inverse_of: :project_locales
    belongs_to :locale,  inverse_of: :project_locales

    belongs_to :latest_translation, class_name: 'Translation'
  end

  class Resource < ActiveRecord::Base
    self.table_name = 'base_resource'

    belongs_to :project, inverse_of: :resources

    has_many :entities, inverse_of: :resource
    has_many :translated_resources, inverse_of: :resource

    scope :by_path, ->(path) {
      where(path: path)
    }
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

    scope :by_resource_and_key, ->(resource, key) {
      by_resource(resource).by_key(key)
    }

    scope :by_resource, ->(resource) {
      where(resource_id: Resource.by_path(resource))
    }

    scope :by_key, ->(key) {
      where(key: key)
    }

    scope :by_string, ->(string) {
      where(%[regexp_replace(lower(trim(string)), '[^\\w]+', '', 'g') = regexp_replace(lower(trim(?)), '[^\\w]+', '', 'g')], string)
    }

    scope :missing_translations_on, ->(locale) {
      project = current_scope.proxy_association.owner
      unless project.is_a?(Project)
        raise ArgumentError, "Can only be called from a Project scope"
      end

      where.not(id: project.translations.by_locale(locale).select(:entity_id))
    }
  end

  class Translation < ActiveRecord::Base
    self.table_name = 'base_translation'

    belongs_to :entity, inverse_of: :translations
    belongs_to :locale, inverse_of: :translations
    belongs_to :user,   inverse_of: :translations

    belongs_to :approved_user,   class_name: 'User'
    belongs_to :unapproved_user, class_name: 'User'
    belongs_to :rejected_user,   class_name: 'User'
    belongs_to :unrejected_user, class_name: 'User'

    has_many :memories, inverse_of: :translation

    scope :approved, -> { where(approved: true) }

    scope :by_approver, ->(username) {
      where(approved_user_id: User.by_username(username))
    }

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

    def translated_resource
      self.resource.translated_resources.
        where(locale: self.locale).first!
    end

    private
      def update_latest_translation_ids
        [ self.translated_resource,
          self.project_locale,
          self.locale,
          self.project,
        ].each do |object|
          object.update_column(:latest_translation_id, self.id)
        end
      end

      def update_translation_counters
        [ self.translated_resource,
          self.project_locale,
          self.locale,
          self.project,
        ].each do |object|
          object.increment!(:translated_strings, 1)
        end
      end

      def create_memory
        memory = Memory.new

        memory.source      = self.entity.string
        memory.target      = self.string

        memory.entity      = self.entity
        memory.locale      = self.locale
        memory.project     = self.project

        memory.translation = self

        memory.save!
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

    scope :by_username, ->(uid) { where(username: uid) }

    def self.lookup(uid)
      by_username(uid).first
    end

    def self.default
      lookup('v.chiartano')
    end

    def self.lookup_or_default(uid)
      lookup(uid) || default
    end
  end
end
