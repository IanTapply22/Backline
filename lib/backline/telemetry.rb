module Backline
  module Telemetry
    class << self
      def emit(event, payload = {})
        ActiveSupport::Notifications.instrument(event, payload)
      end
    end
  end
end
