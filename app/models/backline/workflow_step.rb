class Backline::WorkflowStep < ApplicationRecord
  self.table_name = "backline_workflow_steps"

  belongs_to :workflow, class_name: "Backline::WorkflowRecord"
  belongs_to :job_execution, class_name: "Backline::JobExecution", optional: true

  def arguments
    JSON.parse(arguments_json)
  rescue JSON::ParserError
    []
  end

  def metadata
    JSON.parse(metadata_json)
  rescue JSON::ParserError
    {}
  end
end
