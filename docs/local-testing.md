# Local Testing

Backline is easiest to smoke-test in two modes:

## 1. Dogfood this repo as the demo host app

```bash
bin/rails db:migrate
bin/rails db:schema:load:cache
bin/rails db:schema:load:queue
bin/rails db:schema:load:cable
bin/rails server
bin/backline
```

Then open `http://localhost:3000/backline`.

## 2. Test the real install flow in a disposable Rails app

```bash
./script/test-install /tmp/backline-smoke
cd /tmp/backline-smoke
bin/rails server
bin/backline
```

Then open:

- `http://localhost:3000/` for the smoke playground
- `http://localhost:3000/backline` for the Backline dashboard

The smoke playground gives you one-click demo requests for:

- default jobs
- critical jobs
- scheduled jobs
- intentionally failing jobs
- unique jobs
- rate-limited jobs
- batches
- workflows

That script generates a fresh Rails app, installs Backline from this checkout via a local path gem, runs the installer, migrates the database, and copies in the playground controller, views, and demo jobs.
If you want to run the installer manually, use `bin/rails generate backline:install`.
If you hit missing `solid_queue_*` tables, explicitly load the extra schemas in the host app:

```bash
bin/rails db:prepare
bin/rails db:schema:load:cache
bin/rails db:schema:load:queue
bin/rails db:schema:load:cable
```

Backline depends on Solid Queue's schema being loaded into the `queue` database, not just Backline's own migration.
