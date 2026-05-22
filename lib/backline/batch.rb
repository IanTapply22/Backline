module Backline
  class Batch
    class << self
      def enqueue(name:, jobs:, metadata: {})
        batch = Backline::BatchRecord.create!(
          name: name,
          total_jobs: jobs.size,
          metadata_json: metadata.to_json
        )

        jobs.each do |entry|
          entry.fetch(:job).perform_later(
            *Array(entry[:args]),
            tenant: entry[:tenant],
            user: entry[:user],
            metadata: entry[:metadata] || {},
            batch: batch
          )
        end

        batch
      end
    end
  end
end
