class Backline::MetricsController < Backline::ApplicationController
  protect_from_forgery with: :null_session

  def show
    Backline.config.metrics_authenticator&.call(self)
    return if performed?

    render plain: Backline::PrometheusExporter.render, content_type: "text/plain; version=0.0.4"
  end
end
