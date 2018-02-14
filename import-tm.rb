require 'active_record'
require './txml'

unless (f = ARGV[0])
  puts "Usage: #$0 <source file>"
  exit 1
end

begin
  txml = Txml.parse_file(f)
rescue
  puts $!
  exit 2
end

puts txml.translations
