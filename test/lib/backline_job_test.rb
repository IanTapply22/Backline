require "test_helper"

class BacklineJobTest < ActiveSupport::TestCase
  class ExampleJob
    include Backline::Job

    queue :mailers
    priority 7
    retries 4
    unique_for 10.minutes
    rate_limit key: "sendgrid", limit: 100, period: 1.minute
  end

  test "stores dsl configuration" do
    assert_equal "mailers", ExampleJob.backline_queue_name
    assert_equal 7, ExampleJob.backline_priority
    assert_equal 4, ExampleJob.backline_retry_limit
    assert_equal 10.minutes, ExampleJob.backline_unique_for
    assert_equal "sendgrid", ExampleJob.backline_rate_limit_options[:key]
  end
end
