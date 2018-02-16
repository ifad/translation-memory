require 'active_record'
require './shared'

module Pontoon
  def self.connect(spec)
    ActiveRecord::Base.establish_connection(spec)
  end

  def self.import!(translations, project_name)

    project = Project.lookup(project_name)
    raise "Project not found: #{project_name}" unless project

    translations.each do |translation|

      entity = Entity.find_string(translation.source)

    end
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
  end

  class Entity < ActiveRecord::Base
    self.table_name = 'base_entity'

    belongs_to :resource, inverse_of: :entities

    has_many :translations, inverse_of: :entity
    has_many :memories,     inverse_of: :entity

    def self.find_string(string)
      where('trim(string) = ?', string).first
    end
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
  end
end
