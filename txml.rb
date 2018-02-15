require './shared'

#
# <mtf>
#   <conceptGrp>class:ConceptGroup</conceptGrp>
#
#   [... <conceptGrp></conceptGrp> ...]
# </mtf>
#
module Txml
  def self.parse_file(*args)
    Document.parse_file(*args)
  end

  class Document < Element
    def format_inspect
      "concept_groups: #{concept_groups.size}"
    end

    def concept_groups
      elems(ConceptGroup, '/mtf/conceptGrp')
    end

    def translations
      concept_groups.inject([]) do |ret, cg|

        source = cg.language_groups.first
        targets = cg.language_groups[1..-1]

        targets.each do |lg|
          lg.term_groups.each.with_index do |tg, i|
            source_tg = source.term_groups[i] || source.term_groups.first

            xl = Translation.new
            xl.language   = lg.language
            xl.user       = tg.created_by
            xl.created_at = tg.created_at
            xl.updated_at = tg.updated_at
            xl.source     = source_tg.term
            xl.target     = tg.term

            ret.push xl
          end
        end

        ret

      end
    end
  end

  #
  # <conceptGrp>
  #   <languageGrp>class:LanguageGroup</languageGrp>
  #
  #   [... <languageGrp></languageGrp> ...]
  # </conceptGrp>
  #
  class ConceptGroup < Element
    def format_inspect
      "languages: #{languages} groups: #{language_groups.size}"
    end

    def languages
      language_groups.map(&:language)
    end

    def language_groups
      elems(LanguageGroup, './languageGrp')
    end
  end

  #
  # <languageGrp>
  #   <language lang="EN" type="English"/>
  #   <termGrp>class:TermGroup</termGrp>
  #
  #   [... <termGrp></termGrp> ...]
  # </languageGrp>
  #
  class LanguageGroup < Element
    def format_inspect
      "language: #{language} terms: #{term_groups.size}"
    end

    def language
      text('./language[@lang]/@lang')
    end

    def term_groups
      elems(TermGroup, './termGrp')
    end
  end

  #
  # <termGrp>
  #   <term>FOO BAR!</term>
  #   <transacGrp>
  #     <transac type="origination">b.couto</transac>
  #     <date>2018-01-19T15:07:04</date>
  #   </transacGrp>
  #   <transacGrp>
  #     <transac type="modification">b.couto</transac>
  #     <date>2018-01-19T15:07:04</date>
  #   </transacGrp>
  # </termGrp>
  #
  class TermGroup < Element
    def format_inspect
      "term: #{term}"
    end

    def term
      text('./term/text()')
    end

    def created_by
      text('./transacGrp/transac[@type="origination"]')
    end

    def created_at
      time('./transacGrp/transac[@type="origination"]/following-sibling::date')
    end

    def updated_by
      text('./transacGrp/transac[@type="modification"]')
    end

    def updated_at
      time('./transacGrp/transac[@type="modification"]/following-sibling::date')
    end
  end
end
