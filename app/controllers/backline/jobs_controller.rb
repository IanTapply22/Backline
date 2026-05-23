class Backline::JobsController < Backline::ApplicationController
  def index
    @jobs = Backline::JobExecution.search(filter_params).limit(100)
    @queues = Backline::JobExecution.distinct.order(:queue_name).pluck(:queue_name)
  end

  def show
    @job = Backline::JobExecution.find(params[:id])
  end

  def retry_job
    job = Backline::JobExecution.find(params[:id])
    job.requeue!
    redirect_to job_path(job), notice: "Job requeued."
  end

  def kill_job
    job = Backline::JobExecution.find(params[:id])

    if job.kill!
      redirect_back fallback_location: job_path(job), notice: "Job killed."
    else
      redirect_back fallback_location: job_path(job), alert: "Job could not be killed."
    end
  end

  private

  def filter_params
    params.permit(:status, :queue, :tenant, :user, :job_class, :query)
  end
end
