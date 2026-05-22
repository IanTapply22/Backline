# Backline

Backline is a Rails-first background job system focused on safer defaults, richer visibility, and built-in features that are often paywalled elsewhere.

## Install

Add Backline to your app:

```ruby
# Gemfile
gem "backline"
```

Install it:

```bash
bundle install
bin/rails generate backline:install
bin/rails db:prepare
bin/rails db:schema:load:queue
```

Mounting the dashboard is handled by `backline:install`, which adds:

```ruby
mount Backline::Engine => "/backline", as: "backline_ui"
```

Generate a job:

```bash
bin/rails generate backline:job send_email
```

Run the worker:

```bash
bundle exec backline
```

Or, after install:

```bash
bin/backline
```

## Job API

```ruby
class SendEmailJob
  include Backline::Job

  queue :mailers
  priority 5
  retries 5
  unique_for 10.minutes
  rate_limit key: "sendgrid", limit: 100, period: 1.minute
  tenant { |user_id| User.find(user_id).account_id }
  user { |user_id| user_id }

  def perform(user_id)
    UserMailer.welcome(user_id).deliver_now
  end
end
```

Enqueue jobs like Sidekiq:

```ruby
SendEmailJob.perform_async(42)
SendEmailJob.perform_in(5.minutes, 42)
SendEmailJob.perform_at(5.minutes.from_now, 42)
```

Use `retries` instead of `retry` because bare `retry` is a Ruby keyword.

## Included Features

- Reliable execution history with lease tracking and stale-job requeue hooks.
- Built-in uniqueness locks.
- Retries with dead-letter state.
- Delayed and scheduled jobs.
- Batch fan-out and chained workflows.
- Rate limiting metadata and enforcement windows.
- Priority queues and weighted queue visibility.
- Multi-tenant and user-scoped search metadata.
- Dashboard for queues, failed jobs, worker health, recurring tasks, and metrics.
- Prometheus-friendly `/backline/metrics`.

## Local Development

You can dogfood this repo directly as a demo host app:

```bash
bin/rails db:migrate
bin/rails server
bin/backline
```

Then open `http://localhost:3000/backline`.

You can also smoke-test the real install flow in a fresh Rails app using [docs/local-testing.md](/home/tapps/backline/docs/local-testing.md:1) and [script/test-install](/home/tapps/backline/script/test-install:1).
