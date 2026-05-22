module Smoke
  class RateLimitedJob
    include Backline::Job

    queue :mailers
    priority 3
    retries 1
    rate_limit key: "smoke-api", limit: 2, period: 1.minute, scope: :tenant

    def perform(message)
      Rails.logger.info("[Smoke::RateLimitedJob] #{message}")
    end
  end
end
