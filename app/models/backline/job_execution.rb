class Backline::JobExecution < ApplicationRecord
  self.table_name = "backline_job_executions"

  belongs_to :batch, class_name: "Backline::BatchRecord", optional: true
  belongs_to :workflow, class_name: "Backline::WorkflowRecord", optional: true
  has_one :unique_lock, class_name: "Backline::UniqueLock", dependent: :destroy

  enum :status, {
    queued: "queued",
    scheduled: "scheduled",
    running: "running",
    succeeded: "succeeded",
    failed: "failed",
    dead: "dead",
    rate_limited: "rate_limited"
  }, default: :queued, validate: true

  scope :pending, -> { where(status: [ "queued", "scheduled", "rate_limited" ]) }
  scope :recent_first, -> { order(created_at: :desc) }

  def arguments
    JSON.parse(arguments_json)
  rescue JSON::ParserError
    []
  end

  def metadata
    JSON.parse(metadata_json)
  rescue JSON::ParserError
    {}
  end

  def finished?
    finished_at.present? || succeeded? || dead?
  end

  def job_klass
    job_class.constantize
  end

  def retryable?
    attempts_count < max_attempts
  end

  def start_processing!
    update!(
      status: "running",
      started_at: Time.current,
      lease_expires_at: Backline.config.lease_duration.from_now
    )
  end

  def mark_succeeded!
    update!(
      status: "succeeded",
      finished_at: Time.current,
      lease_expires_at: nil
    )
  end

  def mark_failed!(error)
    update!(
      status: "failed",
      attempts_count: attempts_count + 1,
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: Array(error.backtrace).first(20).join("\n"),
      lease_expires_at: nil
    )
  end

  def schedule_retry!
    delay_seconds = [ attempts_count**2, 1 ].max * 15
    update!(
      status: "scheduled",
      scheduled_at: delay_seconds.seconds.from_now,
      available_at: delay_seconds.seconds.from_now,
      finished_at: nil
    )
  end

  def mark_dead!
    update!(
      status: "dead",
      finished_at: Time.current
    )
  end

  def requeue!
    update!(
      status: "queued",
      attempts_count: 0,
      scheduled_at: Time.current,
      available_at: Time.current,
      started_at: nil,
      finished_at: nil,
      error_class: nil,
      error_message: nil,
      error_backtrace: nil,
      lease_expires_at: nil
    )

    Backline::RunnerJob.set(queue: queue_name, priority: priority).perform_later(id)
  end

  def self.search(params = {})
    relation = recent_first
    relation = relation.where(status: params[:status]) if params[:status].present?
    relation = relation.where(queue_name: params[:queue]) if params[:queue].present?
    relation = relation.where(tenant_key: params[:tenant]) if params[:tenant].present?
    relation = relation.where(user_key: params[:user]) if params[:user].present?
    relation = relation.where("job_class LIKE ?", "%#{params[:job_class]}%") if params[:job_class].present?

    if params[:query].present?
      term = "%#{params[:query]}%"
      relation = relation.where("arguments_json LIKE :term OR metadata_json LIKE :term", term: term)
    end

    relation
  end
end
