require './pontoon'

project_slug, locale, mode = ARGV

mode = mode ? mode.intern : :condensed

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

Pontoon.export_missing_translations_for(project, locale, mode)
