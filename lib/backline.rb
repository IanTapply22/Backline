require "digest"
require "json"
require "rails"
require "active_support/core_ext/integer/time"

require_relative "backline/version"
require_relative "backline/configuration"

module Backline
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config)
    end
  end
  autoload :Telemetry, "backline/telemetry"
  autoload :RateLimiter, "backline/rate_limiter"
  autoload :Enqueuer, "backline/enqueuer"
  autoload :Job, "backline/job"
  autoload :Batch, "backline/batch"
  autoload :Workflow, "backline/workflow"
  autoload :QueueInspector, "backline/queue_inspector"
  autoload :DashboardSnapshot, "backline/dashboard_snapshot"
  autoload :LeaseMonitor, "backline/lease_monitor"
  autoload :PrometheusExporter, "backline/prometheus_exporter"
  autoload :Cli, "backline/cli"
end

require_relative "backline/engine"
