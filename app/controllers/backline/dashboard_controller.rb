class Backline::DashboardController < Backline::ApplicationController
  def index
    @history_days = params[:days].presence || 30
    @snapshot = Backline::DashboardSnapshot.build(days: @history_days)
  end

  def live
    render json: Backline::DashboardSnapshot.build(days: params[:days].presence || 30)
  end
end
