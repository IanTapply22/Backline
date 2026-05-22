require "uri"

module Backline
  class DashboardSnapshot
    class << self
      HISTORY_WINDOWS = [ 7, 30, 90, 180 ].freeze

      def build(days: 30)
        days = normalize_days(days)

        {
          generated_at: Time.current.iso8601,
          summary: summary,
          queues: Backline::QueueInspector.queue_metrics,
          workers: Backline::QueueInspector.worker_health,
          recent_failures: recent_failures,
          recurring_tasks: recurring_tasks,
          batches: batches,
          workflows: workflows,
          charts: charts(days),
          backend: backend_info
        }
      end

      def recurring_task_entries
        recurring_tasks
      end

      def recent_failure_entries(limit: 8)
        recent_failures(limit: limit)
      end

      private

      def normalize_days(days)
        value = days.to_i
        HISTORY_WINDOWS.include?(value) ? value : 30
      end

      def summary
        succeeded_today = Backline::JobExecution.succeeded.where("finished_at >= ?", Time.current.beginning_of_day).count
        workers = Backline::QueueInspector.worker_health
        running = Backline::JobExecution.running.count
        failed = Backline::JobExecution.failed.count
        dead = Backline::JobExecution.dead.count
        scheduled = Backline::JobExecution.scheduled.count
        rate_limited = Backline::JobExecution.rate_limited.count

        {
          queued: Backline::JobExecution.queued.count,
          scheduled: scheduled,
          running: running,
          failed: failed,
          dead: dead,
          rate_limited: rate_limited,
          retries: failed,
          processed_total: Backline::JobExecution.succeeded.count + dead,
          failure_total: failed + dead,
          busy: running,
          workers: workers.size,
          workers_healthy: workers.count { |worker| worker[:healthy] },
          succeeded_today: succeeded_today,
          active_batches: Backline::BatchRecord.where(status: %w[pending running]).count,
          active_workflows: Backline::WorkflowRecord.where(status: %w[pending running]).count
        }
      end

      def recent_failures(limit: 8)
        Backline::JobExecution.where(status: %w[failed dead]).order(updated_at: :desc).limit(limit).map do |job|
          {
            id: job.id,
            job_class: job.job_class,
            error_class: job.error_class,
            error_message: job.error_message.to_s.truncate(90),
            queue_name: job.queue_name,
            status: job.status,
            failed_at: job.updated_at.iso8601
          }
        end
      end

      def recurring_tasks
        path = Rails.root.join("config/recurring.yml")
        return [] unless path.exist?

        config = YAML.safe_load(path.read, aliases: true)&.fetch(Rails.env, {}) || {}
        config.map do |name, task|
          {
            name: name,
            schedule: task["schedule"],
            queue: task["queue"] || task["queue_name"] || "default"
          }
        end
      rescue StandardError
        []
      end

      def charts(days)
        {
          throughput: throughput_chart,
          history: history_chart(days),
          status_distribution: status_distribution_chart,
          queue_depth: queue_depth_chart
        }
      end

      def batches
        Backline::BatchRecord.order(created_at: :desc).limit(5).map do |batch|
          total = [batch.total_jobs, 1].max

          {
            id: batch.id,
            name: batch.name,
            status: batch.status,
            completed_jobs: batch.completed_jobs,
            failed_jobs: batch.failed_jobs,
            total_jobs: batch.total_jobs,
            progress_percentage: ((batch.completed_jobs + batch.failed_jobs).to_f / total * 100).round(1),
            created_at: batch.created_at.iso8601
          }
        end
      end

      def workflows
        Backline::WorkflowRecord.includes(:steps).order(created_at: :desc).limit(5).map do |workflow|
          step_total = [workflow.total_steps, 1].max
          completed_steps = [workflow.current_step, workflow.total_steps].min

          {
            id: workflow.id,
            name: workflow.name,
            status: workflow.status,
            current_step: workflow.current_step,
            completed_steps: completed_steps,
            total_steps: workflow.total_steps,
            progress_percentage: (completed_steps.to_f / step_total * 100).round(1),
            created_at: workflow.created_at.iso8601
          }
        end
      end

      def throughput_chart
        buckets = 12.times.map { |index| 11 - index }.reverse.map do |offset|
          bucket_start = offset.hours.ago.beginning_of_hour
          bucket_end = bucket_start + 1.hour

          {
            label: bucket_start.strftime("%H:%M"),
            succeeded: Backline::JobExecution.succeeded.where(finished_at: bucket_start...bucket_end).count,
            failed: Backline::JobExecution.where(status: %w[failed dead]).where(updated_at: bucket_start...bucket_end).count,
            queued: Backline::JobExecution.where(created_at: bucket_start...bucket_end).count
          }
        end

        max = buckets.map { |point| [ point[:succeeded], point[:failed], point[:queued] ].max }.max.to_i

        {
          max: [ max, 1 ].max,
          points: buckets
        }
      end

      def history_chart(days)
        start_date = days.days.ago.to_date
        points = start_date.upto(Date.current).map do |date|
          day_range = date.beginning_of_day..date.end_of_day

          {
            label: date.strftime("%m-%d"),
            processed: Backline::JobExecution.succeeded.where(finished_at: day_range).count,
            failed: Backline::JobExecution.where(status: %w[failed dead]).where(updated_at: day_range).count
          }
        end

        max = points.map { |point| [ point[:processed], point[:failed] ].max }.max.to_i

        {
          days: days,
          max: [ max, 1 ].max,
          points: points
        }
      end

      def status_distribution_chart
        counts = Backline::JobExecution.group(:status).count
        total = counts.values.sum

        slices = %w[queued scheduled running succeeded failed dead rate_limited].map do |status|
          value = counts.fetch(status, 0)
          percentage = total.zero? ? 0 : ((value.to_f / total) * 100).round(1)

          {
            status: status,
            value: value,
            percentage: percentage
          }
        end

        { total: total, slices: slices }
      end

      def queue_depth_chart
        queues = Backline::QueueInspector.queue_metrics
        max = queues.map { |queue| queue[:queued] }.max.to_i

        {
          max: [ max, 1 ].max,
          queues: queues
        }
      end

      def backend_info
        redis_url = ENV["REDIS_URL"].presence
        redis_enabled = redis_url.present?

        {
          queue_adapter: ActiveJob::Base.queue_adapter.class.name,
          storage_backend: redis_enabled ? "redis" : "solid_queue",
          redis: {
            configured: redis_enabled,
            url: redis_enabled ? sanitized_redis_url(redis_url) : nil,
            note: redis_enabled ? "Redis URL detected from environment." : "Redis not configured for this environment."
          },
          databases: database_info,
          recurring_configured: recurring_tasks.size
        }
      end

      def database_info
        configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)

        configs.map do |config|
          {
            name: config.name,
            adapter: config.adapter,
            database: config.database
          }
        end
      rescue StandardError
        []
      end

      def sanitized_redis_url(url)
        uri = URI.parse(url)
        uri.password = "[FILTERED]" if uri.password
        uri.to_s
      rescue URI::InvalidURIError
        "[invalid REDIS_URL]"
      end
    end
  end
end
