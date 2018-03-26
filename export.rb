require './pontoon'
require 'pry'

project_slug, locale = ARGV

unless project_slug && locale
  puts "Usage: #$0 <project slug> <locale> [single|condensed]"
  exit 1
end

Pontoon.connect!

@project = Pontoon::Project.lookup(project_slug)
unless @project
  puts "Project `#{project_slug}' was not found"
  exit 2
end

@locale = @project.locales.lookup(locale)
unless @locale
  puts "Project `#{project_slug}` is not translated to `#{locale}`"
  exit 3
end

def export(translations)
  Pontoon.export_translations translations, @project, @locale
end

Pontoon.cheer "Call export() passing the translations you want to get."

Scope = @project.translations.by_locale(@locale)

binding.pry
