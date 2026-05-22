class Backline::BatchRecord < ApplicationRecord
  self.table_name = "backline_batches"

  has_many :job_executions, class_name: "Backline::JobExecution", foreign_key: :batch_id, dependent: :nullify

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

  def register_execution!(_execution)
    update!(status: "running")
  end

  def record_completion!
    completed = completed_jobs + 1
    attrs = { completed_jobs: completed }
    if completed + failed_jobs >= total_jobs
      attrs[:status] = failed_jobs.zero? ? "succeeded" : "failed"
      attrs[:finished_at] = Time.current
    end
    update!(attrs)
  end

  def record_failure!
    failed = failed_jobs + 1
    attrs = { failed_jobs: failed }

    if completed_jobs + failed >= total_jobs
      attrs[:status] = "failed"
      attrs[:finished_at] = Time.current
    end

    update!(attrs)
  end
end
