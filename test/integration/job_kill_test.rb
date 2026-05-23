require "test_helper"

class JobKillTest < ActionDispatch::IntegrationTest
  test "kills a job from the member action" do
    job = Backline::JobExecution.create!(
      job_class: "ExampleJob",
      queue_name: "default",
      status: "queued",
      arguments_json: "[]",
      metadata_json: "{}"
    )

    post "/jobs/#{job.id}/kill_job"

    assert_redirected_to "/jobs/#{job.id}"
    assert_equal "Job killed.", flash[:notice]

    job.reload
    assert_equal "dead", job.status
  end
end
