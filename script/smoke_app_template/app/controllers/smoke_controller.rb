class SmokeController < ApplicationController
  def index
    @counts = Backline::JobExecution.group(:status).count
  end

  def enqueue_default
    Smoke::EchoJob.perform_async("hello from the smoke app", tenant: "acme", user: "user-1", metadata: { source: "playground" })
    redirect_to root_path, notice: "Queued a default job."
  end

  def enqueue_critical
    Smoke::CriticalJob.perform_async("critical path", tenant: "acme", user: "ops-1")
    redirect_to root_path, notice: "Queued a critical job."
  end

  def enqueue_scheduled
    Smoke::EchoJob.perform_in(30.seconds, "scheduled hello", tenant: "beta", user: "user-2", metadata: { source: "scheduled" })
    redirect_to root_path, notice: "Queued a scheduled job for 30 seconds from now."
  end

  def enqueue_failure
    Smoke::FailingJob.perform_async("explode", tenant: "acme", user: "qa-1")
    redirect_to root_path, notice: "Queued a failing job."
  end

  def enqueue_unique
    3.times do
      Smoke::UniqueJob.perform_async("same-payload", tenant: "acme", user: "user-3")
    end

    redirect_to root_path, notice: "Attempted to queue the same unique job three times."
  end

  def enqueue_rate_limited
    5.times do |index|
      Smoke::RateLimitedJob.perform_async("request-#{index}", tenant: "api-demo", user: "worker-#{index}")
    end

    redirect_to root_path, notice: "Queued five rate-limited jobs."
  end

  def enqueue_batch
    Backline::Batch.enqueue(
      name: "Smoke batch #{Time.current.to_i}",
      jobs: [
        { job: Smoke::EchoJob, args: [ "batch-one" ], tenant: "batch", user: "user-a" },
        { job: Smoke::EchoJob, args: [ "batch-two" ], tenant: "batch", user: "user-b" },
        { job: Smoke::CriticalJob, args: [ "batch-critical" ], tenant: "batch", user: "user-c" }
      ],
      metadata: { source: "playground" }
    )

    redirect_to root_path, notice: "Queued a demo batch."
  end

  def enqueue_workflow
    Backline::Workflow.enqueue(
      name: "Smoke workflow #{Time.current.to_i}",
      steps: [
        { job: Smoke::EchoJob, args: [ "workflow-step-1" ], queue: "default", priority: 1, metadata: { step: 1 } },
        { job: Smoke::CriticalJob, args: [ "workflow-step-2" ], queue: "critical", priority: 10, metadata: { step: 2 } },
        { job: Smoke::EchoJob, args: [ "workflow-step-3" ], queue: "mailers", priority: 5, metadata: { step: 3 } }
      ],
      metadata: { source: "playground" }
    )

    redirect_to root_path, notice: "Queued a demo workflow."
  end
end
