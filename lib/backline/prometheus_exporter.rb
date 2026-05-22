module Backline
  class PrometheusExporter
    JOB_STATUSES = %w[queued scheduled running succeeded failed dead rate_limited].freeze
    BATCH_STATUSES = %w[pending running succeeded failed].freeze
    WORKFLOW_STATUSES = %w[pending running succeeded failed].freeze

    class << self
      def render
        lines = []

        append_job_metrics(lines)
        append_queue_metrics(lines)
        append_worker_metrics(lines)
        append_batch_metrics(lines)
        append_workflow_metrics(lines)
        append_recurring_metrics(lines)
        append_runtime_metrics(lines)

        lines.join("\n") + "\n"
      end

      private

      def append_job_metrics(lines)
        counts = Backline::JobExecution.group(:status).count
        queue_status_counts = Backline::JobExecution.group(:queue_name, :status).count

        lines << "# HELP backline_jobs_total Current number of job executions by status."
        lines << "# TYPE backline_jobs_total gauge"
        JOB_STATUSES.each do |status|
          lines << metric_line("backline_jobs_total", counts.fetch(status, 0), status: status)
        end

        lines << "# HELP backline_jobs_by_queue_total Current number of job executions by queue and status."
        lines << "# TYPE backline_jobs_by_queue_total gauge"
        queue_status_counts.each do |(queue_name, status), count|
          lines << metric_line("backline_jobs_by_queue_total", count, queue: queue_name, status: status)
        end

        lines << "# HELP backline_job_attempts_total Sum of attempts recorded across all job executions."
        lines << "# TYPE backline_job_attempts_total gauge"
        lines << simple_metric("backline_job_attempts_total", Backline::JobExecution.sum(:attempts_count))

        lines << "# HELP backline_jobs_with_unique_lock_total Number of job executions currently holding a unique lock."
        lines << "# TYPE backline_jobs_with_unique_lock_total gauge"
        lines << simple_metric("backline_jobs_with_unique_lock_total", Backline::UniqueLock.count)
      end

      def append_queue_metrics(lines)
        queue_metrics = Backline::QueueInspector.queue_metrics

        lines << "# HELP backline_queue_depth Current number of pending jobs per queue."
        lines << "# TYPE backline_queue_depth gauge"
        queue_metrics.each do |queue|
          lines << metric_line("backline_queue_depth", queue[:queued], queue: queue[:name])
        end

        lines << "# HELP backline_queue_latency_seconds Current oldest pending job age per queue in seconds."
        lines << "# TYPE backline_queue_latency_seconds gauge"
        queue_metrics.each do |queue|
          lines << metric_line("backline_queue_latency_seconds", queue[:latency_seconds], queue: queue[:name])
        end

        lines << "# HELP backline_queue_weight Configured scheduling weight per queue."
        lines << "# TYPE backline_queue_weight gauge"
        queue_metrics.each do |queue|
          lines << metric_line("backline_queue_weight", queue[:weight], queue: queue[:name])
        end
      end

      def append_worker_metrics(lines)
        workers = Backline::QueueInspector.worker_health

        lines << "# HELP backline_workers_total Number of worker processes known to Backline."
        lines << "# TYPE backline_workers_total gauge"
        lines << simple_metric("backline_workers_total", workers.size)

        lines << "# HELP backline_workers_healthy_total Number of healthy worker processes."
        lines << "# TYPE backline_workers_healthy_total gauge"
        lines << simple_metric("backline_workers_healthy_total", workers.count { |worker| worker[:healthy] })

        lines << "# HELP backline_workers_by_kind_total Number of worker processes by kind."
        lines << "# TYPE backline_workers_by_kind_total gauge"
        workers.group_by { |worker| worker[:kind].presence || "unknown" }.each do |kind, entries|
          lines << metric_line("backline_workers_by_kind_total", entries.size, kind: kind)
        end
      end

      def append_batch_metrics(lines)
        status_counts = Backline::BatchRecord.group(:status).count

        lines << "# HELP backline_batches_total Current number of batches by status."
        lines << "# TYPE backline_batches_total gauge"
        BATCH_STATUSES.each do |status|
          lines << metric_line("backline_batches_total", status_counts.fetch(status, 0), status: status)
        end

        lines << "# HELP backline_batch_jobs_total Total jobs tracked across all batches."
        lines << "# TYPE backline_batch_jobs_total gauge"
        lines << simple_metric("backline_batch_jobs_total", Backline::BatchRecord.sum(:total_jobs))

        lines << "# HELP backline_batch_completed_jobs_total Total completed jobs tracked across all batches."
        lines << "# TYPE backline_batch_completed_jobs_total gauge"
        lines << simple_metric("backline_batch_completed_jobs_total", Backline::BatchRecord.sum(:completed_jobs))

        lines << "# HELP backline_batch_failed_jobs_total Total failed jobs tracked across all batches."
        lines << "# TYPE backline_batch_failed_jobs_total gauge"
        lines << simple_metric("backline_batch_failed_jobs_total", Backline::BatchRecord.sum(:failed_jobs))
      end

      def append_workflow_metrics(lines)
        status_counts = Backline::WorkflowRecord.group(:status).count

        lines << "# HELP backline_workflows_total Current number of workflows by status."
        lines << "# TYPE backline_workflows_total gauge"
        WORKFLOW_STATUSES.each do |status|
          lines << metric_line("backline_workflows_total", status_counts.fetch(status, 0), status: status)
        end

        lines << "# HELP backline_workflow_steps_total Total steps defined across all workflows."
        lines << "# TYPE backline_workflow_steps_total gauge"
        lines << simple_metric("backline_workflow_steps_total", Backline::WorkflowRecord.sum(:total_steps))

        lines << "# HELP backline_workflow_current_steps_total Total completed-or-current step index across all workflows."
        lines << "# TYPE backline_workflow_current_steps_total gauge"
        lines << simple_metric("backline_workflow_current_steps_total", Backline::WorkflowRecord.sum(:current_step))
      end

      def append_recurring_metrics(lines)
        tasks = Backline::DashboardSnapshot.recurring_task_entries

        lines << "# HELP backline_recurring_tasks_total Number of recurring tasks configured."
        lines << "# TYPE backline_recurring_tasks_total gauge"
        lines << simple_metric("backline_recurring_tasks_total", tasks.size)

        lines << "# HELP backline_recurring_tasks_by_queue_total Number of recurring tasks configured per queue."
        lines << "# TYPE backline_recurring_tasks_by_queue_total gauge"
        tasks.group_by { |task| task[:queue].presence || "default" }.each do |queue, entries|
          lines << metric_line("backline_recurring_tasks_by_queue_total", entries.size, queue: queue)
        end
      end

      def append_runtime_metrics(lines)
        now = Time.current

        lines << "# HELP backline_running_jobs_with_expired_lease_total Number of running jobs whose lease has expired."
        lines << "# TYPE backline_running_jobs_with_expired_lease_total gauge"
        lines << simple_metric(
          "backline_running_jobs_with_expired_lease_total",
          Backline::JobExecution.running.where("lease_expires_at IS NOT NULL AND lease_expires_at < ?", now).count
        )

        lines << "# HELP backline_scheduled_jobs_ready_total Number of scheduled jobs whose available time has passed."
        lines << "# TYPE backline_scheduled_jobs_ready_total gauge"
        lines << simple_metric(
          "backline_scheduled_jobs_ready_total",
          Backline::JobExecution.scheduled.where("available_at IS NOT NULL AND available_at <= ?", now).count
        )
      end

      def simple_metric(name, value)
        "#{name} #{value}"
      end

      def metric_line(name, value, labels = {})
        return "#{name} #{value}" if labels.empty?

        %(#{name}{#{format_labels(labels)}} #{value})
      end

      def format_labels(labels)
        labels.map do |key, value|
          %(#{key}="#{escape_label_value(value)}")
        end.join(",")
      end

      def escape_label_value(value)
        value.to_s.gsub("\\", "\\\\\\").gsub("\n", "\\n").gsub('"', '\"')
      end
    end
  end
end
