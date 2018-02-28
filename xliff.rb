require './shared'

module Xliff
  def self.parse_file(*args)
    Document.parse_file(*args)
  end

  class XMLObject < ::XMLObject
    def namespaces
      { oasis: 'urn:oasis:names:tc:xliff:document:1.2',
        sdl: 'http://sdl.com/FileTypes/SdlXliff/1.0'
      }
    end
  end

  class Document < XMLObject
    def format_inspect
      "source_language: `#{source_language}`, target_language: `#{target_language}`, units: #{units.size} file: `#{original}`"
    end

    def units
      elems(Unit, '/oasis:xliff/oasis:file/oasis:body//oasis:trans-unit[not(@translate="no")]')
    end

    def original
      file['original']
    end

    def source_language
      file['source-language']
    end

    def target_language
      file['target-language']
    end

    def file
      @_file ||= xpath('/oasis:xliff/oasis:file').first
    end

    def translations
      units.inject([]) do |ret, unit|
        next ret if unit.source.strip.empty?

        xl = Translation.new

        xl.language   = self.target_language
        xl.user       = unit.created_by
        xl.created_at = unit.created_at
        xl.updated_at = unit.updated_at
        xl.source     = unit.source
        xl.target     = unit.target

        ret.push xl
      end
    end
  end

  class Unit < XMLObject
    def format_inspect
      "source: #{source.inspect}, target: #{target.inspect}"
    end

    def source
      text('./oasis:seg-source//text()')
    end

    def target
      text('./oasis:target//text()')
    end

    def created_by
      metadata('created_by')
    end

    def created_at
      metadata_time('created_on')
    end

    def updated_by
      metadata('last_modified_by')
    end

    def updated_at
      metadata_time('modified_on')
    end

    private
      def metadata_time(key)
        Time.strptime(metadata(key), '%m/%d/%Y %H:%M:%S')
      rescue
          nil
      end

      def metadata(key)
        segment_def.xpath(%{./sdl:value[@key="#{key}"]/text()}).text
      end

      def segment_def
        xpath('./sdl:seg-defs/sdl:seg[last()]') # last() HACK
      end
  end

end
