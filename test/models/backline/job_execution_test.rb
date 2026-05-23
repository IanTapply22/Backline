require "test_helper"

class Backline::JobExecutionTest < ActiveSupport::TestCase
  test "kill! marks a queued job dead and clears its unique lock" do
    job = Backline::JobExecution.create!(
      job_class: "ExampleJob",
      queue_name: "default",
      status: "queued",
      arguments_json: "[]",
      metadata_json: "{}"
    )
    Backline::UniqueLock.create!(
      digest: "digest-#{job.id}",
      job_execution: job,
      expires_at: 10.minutes.from_now
    )

    assert job.kill!

    job.reload
    assert_equal "dead", job.status
    assert_equal "Backline::JobKilled", job.error_class
    assert_equal "Killed from Backline UI", job.error_message
    assert job.finished_at.present?
    assert_nil job.lease_expires_at
    assert_nil job.unique_lock
  end

  test "kill! returns false for a dead job" do
    job = Backline::JobExecution.create!(
      job_class: "ExampleJob",
      queue_name: "default",
      status: "dead",
      arguments_json: "[]",
      metadata_json: "{}",
      finished_at: Time.current
    )

    assert_not job.kill!
  end
end
