require_relative "lib/backline/version"

Gem::Specification.new do |spec|
  spec.name = "backline"
  spec.version = Backline::VERSION
  spec.authors = [ "OpenAI" ]
  spec.email = [ "support@example.com" ]

  spec.summary = "Rails-first background jobs with safer defaults and a built-in dashboard"
  spec.description = "Backline packages searchable job history, uniqueness, workflows, rate limits, scheduled jobs, and a polished dashboard for Rails applications."
  spec.homepage = "https://example.com/backline"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "app/assets/stylesheets/backline/**/*",
      "app/controllers/backline/**/*",
      "app/jobs/backline/**/*",
      "app/models/backline/**/*",
      "app/views/backline/**/*",
      "app/views/layouts/backline/**/*",
      "config/locales/**/*",
      "config/routes.rb",
      "db/migrate/*.rb",
      "exe/*",
      "lib/**/*",
      "README.md"
    ]
  end
  spec.bindir = "exe"
  spec.executables = [ "backline" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 8.1.0"
  spec.add_dependency "solid_queue"

  spec.metadata["rubygems_mfa_required"] = "false"
end
