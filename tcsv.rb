require './shared'
require 'csv'

class Tcsv
  def self.parse_file(file, options = {})
    contents = File.read(file)
    contents.force_encoding('utf-8')

    options[:col_sep] ||= ENV['COL_SEP'] || ';'

    parse contents, options
  end

  def self.parse(data, options = {})
    new CSV.parse(data, options)
  end

  HEAD = ["Key", "String", "Translation", "Language", "Author", "Date/Time"]

  def initialize(rows)
    @head = rows.shift
    @rows = rows

    unless @head == HEAD
      raise "Invalid heading #{@head.inspect}. Expecting #{HEAD.inspect}."
    end
  end

  def translations
    @rows.inject([]) do |ret, row|
      ret.concat parse_row(row)
    end
  end

  def parse_row(row)
    resource_keys = row[0].split(';')
    source        = row[1]
    target        = row[2]
    language      = row[3]
    author        = row[4]
    created_at    = Time.parse(row[5])

    resource_keys.inject([]) do |ret, resource_key|
      resource, key = resource_key.split(':')

      xl = Translation.new

      xl.resource   = resource
      xl.key        = key
      xl.language   = language
      xl.user       = author
      xl.source     = source
      xl.target     = target
      xl.created_at = created_at
      xl.updated_at = created_at

      ret.push xl
    end
  end
end
