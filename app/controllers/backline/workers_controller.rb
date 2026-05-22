class Backline::WorkersController < Backline::ApplicationController
  def index
    @workers = Backline::QueueInspector.worker_health
  end
end
