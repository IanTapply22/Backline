require "rails/generators"
require "rails/generators/migration"

module Backline
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        if Rails.application.config.active_record.timestamped_migrations
          [ Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % current_migration_number(dirname).to_i.succ ].max
        else
          "%.3d" % current_migration_number(dirname).to_i.succ
        end
      end

      def create_initializer
        template "backline_initializer.rb.tt", "config/initializers/backline.rb"
      end

      def create_config
        template "backline.yml.tt", "config/backline.yml"
      end

      def copy_worker_bin
        template "backline_bin.tt", "bin/backline"
        chmod "bin/backline", 0o755
      end

      def copy_migration
        migration_template "create_backline_tables.rb", "db/migrate/create_backline_tables.rb"
      end

      def mount_engine
        routes_path = "config/routes.rb"
        mount_line = 'mount Backline::Engine => "/backline", as: "backline_ui"'
        routes_source = File.read(routes_path)
        return if routes_source.match?(/mount\s+Backline::Engine\s*=>\s*["']\/backline["']/)

        route mount_line
      end
    end
  end
end
