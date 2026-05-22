module Backline
  class QueueInspector
    WEIGHTS = {
      "critical" => 5,
      "default" => 3,
      "low" => 1
    }.freeze

    class << self
      def queue_metrics
        Backline::JobExecution.pending.group(:queue_name).count.map do |queue_name, count|
          oldest = Backline::JobExecution.pending.where(queue_name: queue_name).minimum(:created_at)
          {
            name: queue_name,
            queued: count,
            weight: Backline.config.queue_weights.fetch(queue_name, WEIGHTS.fetch(queue_name, 1)),
            latency_seconds: oldest ? (Time.current - oldest).to_i : 0
          }
        end.sort_by { |entry| [ -entry[:weight], -entry[:queued] ] }
      end

      def worker_health
        return [] unless defined?(SolidQueue::Process)
        return [] unless solid_queue_process_table_exists?

        SolidQueue::Process.order(last_heartbeat_at: :desc).limit(25).map do |process|
          {
            name: process.name,
            kind: process.kind,
            pid: process.pid,
            hostname: process.hostname,
            heartbeat_at: process.last_heartbeat_at,
            healthy: process.last_heartbeat_at > 1.minute.ago
          }
        end
      rescue ActiveRecord::StatementInvalid
        []
      end

      private

      def solid_queue_process_table_exists?
        SolidQueue::Process.connection_pool.with_connection do |connection|
          connection.data_source_exists?("solid_queue_processes")
        end
      end
    end
  end
end
