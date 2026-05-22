class Backline::WorkflowRecord < ApplicationRecord
  self.table_name = "backline_workflows"

  has_many :steps, class_name: "Backline::WorkflowStep", foreign_key: :workflow_id, dependent: :destroy
  has_many :job_executions, class_name: "Backline::JobExecution", foreign_key: :workflow_id, dependent: :nullify

  enum :status, {
    pending: "pending",
    running: "running",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :pending, validate: true

  def metadata
    JSON.parse(metadata_json)
  rescue JSON::ParserError
    {}
  end

  def enqueue_next_step!
    step = steps.order(:position).find_by(position: current_step)
    unless step
      update!(status: "succeeded", finished_at: Time.current)
      return
    end

    update!(status: "running")
    execution = step.job_class.constantize.perform_later(
      *step.arguments,
      workflow: self,
      metadata: step.metadata,
      queue: step.queue_name,
      priority: step.priority
    )
    step.update!(job_execution: execution, status: "enqueued")
  end

  def attach_execution!(_execution)
  end

  def advance_from!(execution)
    step = steps.find_by(job_execution_id: execution.id)
    return unless step

    next_step = step.position + 1
    step.update!(status: "succeeded")
    update!(current_step: next_step)
    enqueue_next_step!
  end

  def fail_from!(execution)
    step = steps.find_by(job_execution_id: execution.id)
    step&.update!(status: "failed")
    update!(status: "failed", finished_at: Time.current)
  end
end
