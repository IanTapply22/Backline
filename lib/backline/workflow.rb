module Backline
  class Workflow
    class << self
      def enqueue(name:, steps:, metadata: {})
        workflow = Backline::WorkflowRecord.create!(
          name: name,
          total_steps: steps.size,
          metadata_json: metadata.to_json
        )

        steps.each_with_index do |step, index|
          workflow.steps.create!(
            position: index,
            job_class: step.fetch(:job).name,
            queue_name: step.fetch(:queue, "default"),
            priority: step.fetch(:priority, 0),
            arguments_json: Array(step[:args]).to_json,
            metadata_json: (step[:metadata] || {}).to_json
          )
        end

        workflow.enqueue_next_step!
        workflow
      end
    end
  end
end
