class CreateBacklineTables < ActiveRecord::Migration[8.1]
  def change
    create_table :backline_batches do |t|
      t.string :name, null: false
      t.string :status, null: false, default: "pending"
      t.integer :total_jobs, null: false, default: 0
      t.integer :completed_jobs, null: false, default: 0
      t.integer :failed_jobs, null: false, default: 0
      t.text :metadata_json, null: false, default: "{}"
      t.datetime :finished_at
      t.timestamps
    end

    add_index :backline_batches, :status

    create_table :backline_workflows do |t|
      t.string :name, null: false
      t.string :status, null: false, default: "pending"
      t.integer :current_step, null: false, default: 0
      t.integer :total_steps, null: false, default: 0
      t.text :metadata_json, null: false, default: "{}"
      t.datetime :finished_at
      t.timestamps
    end

    add_index :backline_workflows, :status

    create_table :backline_job_executions do |t|
      t.string :job_class, null: false
      t.string :queue_name, null: false, default: "default"
      t.integer :priority, null: false, default: 0
      t.string :status, null: false, default: "queued"
      t.text :arguments_json, null: false, default: "[]"
      t.text :metadata_json, null: false, default: "{}"
      t.string :tenant_key
      t.string :user_key
      t.string :unique_key
      t.string :rate_limit_key
      t.integer :attempts_count, null: false, default: 0
      t.integer :max_attempts, null: false, default: 0
      t.datetime :scheduled_at
      t.datetime :available_at
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :lease_expires_at
      t.string :error_class
      t.text :error_message
      t.text :error_backtrace
      t.string :active_job_id
      t.references :batch, foreign_key: { to_table: :backline_batches }
      t.references :workflow, foreign_key: { to_table: :backline_workflows }
      t.timestamps
    end

    add_index :backline_job_executions, :status
    add_index :backline_job_executions, [ :queue_name, :status, :priority ]
    add_index :backline_job_executions, [ :tenant_key, :status ]
    add_index :backline_job_executions, :user_key
    add_index :backline_job_executions, :unique_key
    add_index :backline_job_executions, :lease_expires_at
    add_index :backline_job_executions, :scheduled_at

    create_table :backline_unique_locks do |t|
      t.string :digest, null: false
      t.references :job_execution, null: false, foreign_key: { to_table: :backline_job_executions }
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :backline_unique_locks, :digest, unique: true
    add_index :backline_unique_locks, :expires_at

    create_table :backline_workflow_steps do |t|
      t.references :workflow, null: false, foreign_key: { to_table: :backline_workflows }
      t.integer :position, null: false
      t.string :job_class, null: false
      t.string :queue_name, null: false, default: "default"
      t.integer :priority, null: false, default: 0
      t.text :arguments_json, null: false, default: "[]"
      t.text :metadata_json, null: false, default: "{}"
      t.string :status, null: false, default: "pending"
      t.references :job_execution, foreign_key: { to_table: :backline_job_executions }
      t.timestamps
    end

    add_index :backline_workflow_steps, [ :workflow_id, :position ], unique: true
    add_index :backline_workflow_steps, :status

    create_table :backline_rate_limit_windows do |t|
      t.string :scope, null: false
      t.string :key, null: false
      t.integer :limit_value, null: false
      t.integer :period_seconds, null: false
      t.integer :hits_count, null: false, default: 0
      t.datetime :window_started_at, null: false
      t.timestamps
    end

    add_index :backline_rate_limit_windows, [ :scope, :key ], unique: true
    add_index :backline_rate_limit_windows, :window_started_at
  end
end
