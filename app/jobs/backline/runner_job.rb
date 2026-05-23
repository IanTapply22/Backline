class Backline::RunnerJob < ActiveJob::Base
  queue_as :default

  def perform(execution_id)
    execution = Backline::JobExecution.find_by(id: execution_id)
    return unless execution
    return if execution.finished?

    execution.start_processing!
    job_class = execution.job_klass
    job_class.new.perform(*execution.arguments)
    execution.reload
    return if execution.finished?

    execution.mark_succeeded!
    execution.batch&.record_completion!
    execution.workflow&.advance_from!(execution)
    Backline::Telemetry.emit("backline.job.succeeded", execution: execution)
  rescue StandardError => error
    handle_failure(execution, error)
    raise if Rails.env.development?
  end

  private

  def handle_failure(execution, error)
    raise error unless execution

    execution.reload
    return if execution.finished?

    execution.mark_failed!(error)

    if execution.retryable?
      execution.schedule_retry!
      self.class.set(
        queue: execution.queue_name,
        priority: execution.priority,
        wait_until: execution.scheduled_at
      ).perform_later(execution.id)
      Backline::Telemetry.emit("backline.job.retried", execution: execution, error: error)
    else
      execution.mark_dead!
      execution.batch&.record_failure!
      execution.workflow&.fail_from!(execution)
      Backline::Telemetry.emit("backline.job.dead", execution: execution, error: error)
    end
  end
end
