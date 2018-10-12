require './tcsv'

class TcsvSimple < Tcsv

  def self.head
    ["Key", "Resource", "String", "Translation", "Comment", "Author", "Date/Time" ]
  end

  def initialize(rows)
    @lang = ENV['language']
    raise "Error: please pass language=CODE in the environment" unless @lang

    super
  end

  def parse_row(row)
    key        = row[0]
    resource   = row[1]
    source     = row[2]
    target     = row[3]
    author     = row[5]
    created_at = Time.parse(row[6])

    return [ make_translation(resource, key, @lang, author, source, target, created_at) ]
  end
end
