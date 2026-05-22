class Backline::LeaseMonitorJob < ActiveJob::Base
  queue_as :default

  def perform
    Backline::LeaseMonitor.requeue_stale!
  end
end
