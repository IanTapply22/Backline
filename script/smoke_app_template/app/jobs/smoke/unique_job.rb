module Smoke
  class UniqueJob
    include Backline::Job

    queue :mailers
    priority 5
    retries 1
    unique_for 10.minutes

    def perform(message)
      Rails.logger.info("[Smoke::UniqueJob] #{message}")
    end
  end
end
