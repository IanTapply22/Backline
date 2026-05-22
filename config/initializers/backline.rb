settings_path = Rails.root.join("config/backline.yml")
settings = settings_path.exist? ? Rails.application.config_for(:backline) : {}

Backline.configure do |config|
  config.queue_adapter = :solid_queue
  config.lease_duration = settings.fetch("lease_duration_seconds", 300).seconds
  config.queue_weights = settings.fetch("queues", {
    "critical" => 5,
    "default" => 3,
    "low" => 1
  })
end
