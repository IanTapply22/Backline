namespace :backline do
  desc "Install Backline into the current Rails application"
  task install: :environment do
    require "rails/generators"

    Rails::Generators.invoke("backline:install")
  end
end
