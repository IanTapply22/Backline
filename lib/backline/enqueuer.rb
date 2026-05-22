module Backline
  class Enqueuer
    class << self
      def enqueue(job_class, args, wait: nil, wait_until: nil, tenant: nil, user: nil, batch: nil, workflow: nil, metadata: {}, queue: nil, priority: nil)
        scheduled_at = wait_until || (wait && wait.from_now)
        tenant_key = tenant || resolve_proc(job_class.backline_tenant_resolver, args)
        user_key = user || resolve_proc(job_class.backline_user_resolver, args)
        unique_key = Backline::UniqueLock.digest_for(job_class, args, tenant_key)
        initial_status = scheduled_at.present? ? "scheduled" : "queued"

        execution = nil
        existing_execution = nil

        ActiveRecord::Base.transaction do
          execution = Backline::JobExecution.create!(
            job_class: job_class.name,
            queue_name: queue || job_class.backline_queue_name,
            priority: priority || job_class.backline_priority,
            status: initial_status,
            arguments_json: args.to_json,
            metadata_json: metadata.to_json,
            tenant_key: tenant_key,
            user_key: user_key,
            unique_key: unique_key,
            rate_limit_key: Backline::RateLimiter.key_for(job_class, args, tenant_key),
            max_attempts: job_class.backline_retry_limit,
            scheduled_at: scheduled_at,
            available_at: scheduled_at || Time.current,
            batch: batch,
            workflow: workflow
          )

          if job_class.backline_unique_for.present?
            lock = Backline::UniqueLock.acquire!(
              digest: unique_key,
              execution: execution,
              duration: job_class.backline_unique_for
            )

            if lock.job_execution_id != execution.id
              existing_execution = lock.job_execution
              execution.destroy!
            end
          end

          unless existing_execution
            Backline::RateLimiter.check!(job_class, execution)
            active_job = enqueue_runner(execution)
            execution.update!(active_job_id: active_job.job_id)
            batch&.register_execution!(execution)
            workflow&.attach_execution!(execution)
          end
        end

        return existing_execution if existing_execution

        Backline::Telemetry.emit("backline.job.enqueued", execution: execution)
        execution
      end

      private

      def enqueue_runner(execution)
        job = Backline::RunnerJob.set(
          queue: execution.queue_name,
          priority: execution.priority,
          wait_until: execution.available_at || execution.scheduled_at
        )

        job.perform_later(execution.id)
      end

      def resolve_proc(callable, args)
        return if callable.blank?

        callable.call(*args)
      end
    end
  end
end
