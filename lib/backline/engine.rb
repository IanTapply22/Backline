module Backline
  class Engine < ::Rails::Engine
    isolate_namespace Backline

    initializer "backline.assets" do |app|
      app.config.assets.precompile += %w[
        backline/application.css
        backline/chart.umd.min.js
        backline/dashboard.js
      ]
    end

    initializer "backline.active_job" do
      ActiveSupport.on_load(:active_job) do
        self.queue_adapter = Backline.config.queue_adapter
      end
    end

    initializer "backline.notifications" do
      next if defined?(Backline::NOTIFICATIONS_SUBSCRIBED)

      ActiveSupport::Notifications.subscribe(/backline\.job\./) do |name, started, finished, _id, payload|
        Rails.logger.info(
          "[Backline] #{name} duration=#{((finished - started) * 1000).round(1)}ms job=#{payload[:execution]&.job_class} id=#{payload[:execution]&.id}"
        )
      end

      Backline.const_set(:NOTIFICATIONS_SUBSCRIBED, true)
    end
  end
end
