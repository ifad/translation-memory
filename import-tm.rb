require 'active_record'
require './txml'

unless (f = ARGV[0])
  puts "Usage: #$0 <source file>"
  exit 1
end

begin
  xml = Nokogiri::XML.parse File.read(f)
rescue
  puts "Parsing #{f}: #$!"
  exit 2
end

puts Txml.new(xml).translations
