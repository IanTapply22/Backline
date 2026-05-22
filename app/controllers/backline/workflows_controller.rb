class Backline::WorkflowsController < Backline::ApplicationController
  def index
    @workflows = Backline::WorkflowRecord.order(created_at: :desc).limit(50)
  end

  def show
    @workflow = Backline::WorkflowRecord.find(params[:id])
  end
end
