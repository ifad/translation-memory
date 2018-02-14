require 'nokogiri'

class Translation
  attr_accessor :language, :source, :target, :user, :created_at, :updated_at

  def inspect
    "#<Translation #{self}>"
  end

  def to_s
    "[#{language}, #{user}] `#{source}` > `#{target}`"
  end
end

class Element
  def initialize(xml)
    @xml = xml
  end

  protected
  def xpath(decl)
    @xml.xpath(decl)
  end

  def text(decl)
    xpath(decl).text
  end

  def elem(klass, decl)
    klass.new(xpath(decl))
  end

  def elems(klass, decl)
    xpath(decl).map {|xml| klass.new(xml)}
  end
end
