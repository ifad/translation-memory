require './txml'
require './tmx'
require './pontoon'

format, source = ARGV

unless format && source
  puts "Usage: #$0 <format> <source file>"
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
  Pontoon.import!(processed.translations, 'ICP')
rescue
  puts $!
  exit 4
end
