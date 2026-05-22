module Smoke
  class FailingJob
    include Backline::Job

    queue :default
    priority 2
    retries 2

    def perform(_message)
      raise "Intentional smoke failure to exercise retries and dead jobs"
    end
  end
end
