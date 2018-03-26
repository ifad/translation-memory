require './pontoon'
require 'pry'

project_slug, locale = ARGV

unless project_slug && locale
  puts "Usage: #$0 <project slug> <locale> [single|condensed]"
  exit 1
end

Pontoon.connect!

project = Pontoon::Project.lookup(project_slug)
unless project
  puts "Project `#{project_slug}' was not found"
  exit 2
end

locale = project.locales.lookup(locale)
unless locale
  puts "Project `#{project_slug}` is not translated to `#{locale}`"
  exit 3
end

Pontoon.cheer "Please call ret() passing the translations you want to export"

catch :transl do
  def ret(translations)
    @translations = translations
    throw :transl
  end

  Translations = project.translations.by_locale(locale)

  binding.pry
end

unless @translations
  puts "No translations found to export."
  exit 4
end

Pontoon.export_translations @translations, project, locale
