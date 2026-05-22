class Backline::QueuesController < Backline::ApplicationController
  def index
    @queues = Backline::QueueInspector.queue_metrics
  end
end
