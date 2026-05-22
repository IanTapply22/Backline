class Backline::UniqueLock < ApplicationRecord
  self.table_name = "backline_unique_locks"

  belongs_to :job_execution, class_name: "Backline::JobExecution"

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.digest_for(job_class, args, tenant_key)
    Digest::SHA256.hexdigest([ job_class.name, tenant_key, args.to_json ].join(":"))
  end

  def self.acquire!(digest:, execution:, duration:)
    lock = find_by(digest: digest)
    if lock&.expires_at&.future?
      return lock
    end

    lock&.destroy!

    create!(
      digest: digest,
      job_execution: execution,
      expires_at: duration.from_now
    )
  rescue ActiveRecord::RecordNotUnique
    active.find_by!(digest: digest)
  end
end
