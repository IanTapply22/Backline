require "rails/generators"

module Backline
  module Generators
    class JobGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      check_class_collision suffix: "Job"

      def create_job_file
        template "job.rb.tt", File.join("app/jobs", class_path, "#{file_name}_job.rb")
      end

      def create_test_file
        template "job_test.rb.tt", File.join("test/jobs", class_path, "#{file_name}_job_test.rb")
      end
    end
  end
end
