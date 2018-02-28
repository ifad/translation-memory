require './txml'
require './tmx'
require './pontoon'

format, source, project_slug = ARGV

unless format && source
  puts "Usage: #$0 <format> <source file> <project slug>"
  exit 1
end

formats = {
  'tmx'  => Tmx,
  'txml' => Txml,
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
