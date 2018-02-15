require 'active_record'
require './txml'
require './tmx'

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

puts processed.translations
