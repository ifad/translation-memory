require './txml'
require './tmx'
require './xliff'
require './tcsv'
require './pontoon'

format, project_slug, source = ARGV

unless format && source
  puts "Usage: #$0 <format> <project slug> <source file>"
  exit 1
end

formats = {
  'tmx'   => Tmx,
  'txml'  => Txml,
  'xliff' => Xliff,
  'tcsv'  => Tcsv,
}

klass = formats.fetch(format, nil)

unless klass
  puts "Invalid format: #{format}. Available: #{formats.keys.join(', ')}"
  exit 2
end

begin
  processed = klass.parse_file(source)
rescue
  puts $!
  exit 3
end

begin
  Pontoon.connect!
  Pontoon.import!(processed.translations, project_slug)
rescue
  puts $!
  exit 4
end
