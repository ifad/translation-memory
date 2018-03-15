require 'nokogiri'
require 'time'

class Translation
  attr_accessor :language, :source, :target, :user, :created_at, :updated_at, :resource, :key

  def user=(user)
    # Remove DOMAIN\\
    @user = user.sub(/^.+\\/, '')
  end

  def inspect
    "#<Translation #{self}>"
  end

  def to_s
    "[#{language}, #{user}] `#{source}` > `#{target}`"
  end

  def source_excerpt
    self.source.slice(0..35) + '...'
  end

  def language_code
    language.sub(/-\w+$/, '').downcase # Remove country specifier
  end
end

class XMLObject
  def self.parse(text)
    new Nokogiri::XML.parse(text)
  end

  def self.parse_file(file)
    parse File.read(file)
  end

  def initialize(xml)
    @xml = xml
  end

  def xpath(decl)
    @xml.xpath(decl, namespaces)
  end

  def text(decl)
    xpath(decl).text
  end

  def time(decl)
    Time.parse(text(decl))
  end

  def elem(klass, decl, *args)
    klass.new(xpath(decl), *args)
  end

  def elems(klass, decl, *args)
    xpath(decl).map {|xml| klass.new(xml, *args)}
  end

  def namespaces
    {}
  end

  def inspect
    details = self.class === XMLObject ? root_xml_inspect : format_inspect

    "#<#{self.class} #{details}>"
  end

  protected
    def format_inspect
      '/not implemented/'
    end

  private
    def root_xml_inspect
      "#{@xml.version} #{@xml.encoding} root: \"#{@xml.root.node_name}\" \\ #{@xml.root.children.reject(&:text?).map(&:node_name)}"
    end
end
