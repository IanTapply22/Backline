module Smoke
  class EchoJob
    include Backline::Job

    queue :default
    priority 1
    retries 2

    def perform(message)
      Rails.logger.info("[Smoke::EchoJob] #{message}")
    end
  end
end
