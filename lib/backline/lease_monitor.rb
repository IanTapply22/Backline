module Backline
  class LeaseMonitor
    def self.requeue_stale!
      Backline::JobExecution.running.where("lease_expires_at < ?", Time.current).find_each do |execution|
        execution.update!(
          status: "queued",
          started_at: nil,
          scheduled_at: Time.current,
          available_at: Time.current,
          lease_expires_at: nil
        )

        Backline::RunnerJob.set(
          queue: execution.queue_name,
          priority: execution.priority
        ).perform_later(execution.id)
      end
    end
  end
end
