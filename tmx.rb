require './shared'

module Tmx
  def self.parse_file(*args)
    Document.parse_file(*args)
  end

  class Document < Element
    def format_inspect
      "source_language: `#{source_language}` created: `#{created_at}` author: `#{created_by}` units: #{units.count}"
    end

    def source_language
      text('/tmx/header/@srclang')
    end

    def created_at
      time('/tmx/header/@creationdate')
    end

    def created_by
      text('/tmx/header/@creationid')
    end

    def units
      elems(Unit, '/tmx/body/tu', source_language)
    end

    def translations
    end
  end

  class Unit < Element
    def initialize(xml, source_language)
      super(xml)
      @source_language = source_language
    end

    def format_inspect
      "target_language: `foo` created: `#{created_at}` author: `#{created_by}`"
    end

    def created_at
      time('./@creationdate')
    end

    def updated_at
      time('./@changedate')
    end

    def created_by
      text('./@changeid')
    end

    def unit_values
      elems(UnitValue, './tuv')
    end

    def source_unit
      unit_values.find {|uv| uv.language == @source_language }
    end

    def source
      source_unit.string
    end

    def target_unit
      unit_values.find {|uv| uv.language != @source_language }
    end

    def target
      target_unit.string
    end
  end

  class UnitValue < Element
    def format_inspect
      "language: #{language} string: #{string}"
    end

    def language
      text('./@xml:lang')
    end

    def string
      text('./seg')
    end
  end
end
