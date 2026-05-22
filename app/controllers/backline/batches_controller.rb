class Backline::BatchesController < Backline::ApplicationController
  def index
    @batches = Backline::BatchRecord.order(created_at: :desc).limit(50)
  end

  def show
    @batch = Backline::BatchRecord.find(params[:id])
  end
end
