module Smoke
  class CriticalJob
    include Backline::Job

    queue :critical
    priority 10
    retries 2

    def perform(message)
      Rails.logger.info("[Smoke::CriticalJob] #{message}")
    end
  end
end
