module Backline
  module Job
    extend ActiveSupport::Concern

    included do
      class_attribute :backline_queue_name, default: "default"
      class_attribute :backline_priority, default: 0
      class_attribute :backline_retry_limit, default: 0
      class_attribute :backline_unique_for, default: nil
      class_attribute :backline_unique_by, default: nil
      class_attribute :backline_rate_limit_options, default: nil
      class_attribute :backline_tenant_resolver, default: nil
      class_attribute :backline_user_resolver, default: nil
    end

    class_methods do
      def queue(name)
        self.backline_queue_name = name.to_s
      end

      def priority(value)
        self.backline_priority = value.to_i
      end

      def retries(value)
        self.backline_retry_limit = value.to_i
      end

      def unique_for(duration, by: nil)
        self.backline_unique_for = duration
        self.backline_unique_by = by
      end

      def rate_limit(key:, limit:, period:, scope: :job_class)
        self.backline_rate_limit_options = {
          key: key,
          limit: limit,
          period: period,
          scope: scope
        }
      end

      def tenant(&block)
        self.backline_tenant_resolver = block
      end

      def user(&block)
        self.backline_user_resolver = block
      end

      def perform_later(*args, wait: nil, wait_until: nil, tenant: nil, user: nil, batch: nil, workflow: nil, metadata: {}, queue: nil, priority: nil)
        Backline::Enqueuer.enqueue(
          self,
          args,
          wait: wait,
          wait_until: wait_until,
          tenant: tenant,
          user: user,
          batch: batch,
          workflow: workflow,
          metadata: metadata,
          queue: queue,
          priority: priority
        )
      end

      def perform_async(*args, **options)
        perform_later(*args, **options)
      end

      def perform_in(interval, *args, **options)
        perform_later(*args, wait: interval, **options)
      end

      def perform_at(timestamp, *args, **options)
        perform_later(*args, wait_until: timestamp, **options)
      end

      def perform_now(*args)
        new.perform(*args)
      end
    end
  end
end
