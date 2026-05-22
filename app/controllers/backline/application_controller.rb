class Backline::ApplicationController < ActionController::Base
  layout "backline/application"

  helper_method :backline_queue_weights

  private

  def backline_queue_weights
    Backline.config.queue_weights
  end
end
