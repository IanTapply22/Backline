module Backline
  class RateLimiter
    class Limited < StandardError; end

    class << self
      def check!(job_class, execution)
        options = job_class.backline_rate_limit_options
        return unless options.present?

        scope = options[:scope].to_s
        key = execution.rate_limit_key
        period_seconds = options[:period].to_i
        now = Time.current

        window = Backline::RateLimitWindow.find_or_initialize_by(scope: scope, key: key)

        if window.new_record? || window.window_started_at <= now - period_seconds.seconds
          window.assign_attributes(
            limit_value: options[:limit].to_i,
            period_seconds: period_seconds,
            hits_count: 0,
            window_started_at: now
          )
        end

        if window.hits_count >= window.limit_value
          execution.update!(
            status: "rate_limited",
            scheduled_at: window.window_started_at + window.period_seconds.seconds,
            available_at: window.window_started_at + window.period_seconds.seconds
          )
          return execution
        end

        window.hits_count += 1
        window.save!
      end

      def key_for(job_class, args, tenant_key)
        options = job_class.backline_rate_limit_options
        return unless options.present?

        base = options[:key]
        resolved = base.respond_to?(:call) ? base.call(*args) : base
        [ options[:scope], tenant_key, resolved.presence || job_class.name ].compact.join(":")
      end
    end
  end
end
