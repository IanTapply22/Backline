module Backline
  module Cli
    class << self
      def start(argv, root: Dir.pwd)
        environment_path = File.expand_path("config/environment.rb", root)
        unless File.exist?(environment_path)
          abort "Backline must be started from a Rails app root with config/environment.rb present."
        end

        require environment_path
        require "solid_queue/cli"

        SolidQueue::Cli.start(argv)
      end
    end
  end
end
