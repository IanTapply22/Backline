module Backline
  class Configuration
    attr_accessor :queue_adapter, :lease_duration, :queue_weights, :metrics_authenticator

    def initialize
      @queue_adapter = :solid_queue
      @lease_duration = 5.minutes
      @queue_weights = {
        "critical" => 5,
        "default" => 3,
        "low" => 1
      }
      @metrics_authenticator = nil
    end
  end
end
