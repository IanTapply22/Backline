# Local Testing

Backline is easiest to smoke-test by exercising the real install flow in a disposable Rails app:

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
If you hit missing `solid_queue_*` or `solid_cable_*` tables, make sure the host app defines `queue` and `cable` databases in `config/database.yml`, then explicitly load those schemas:

```bash
bin/rails db:prepare
bin/rails db:schema:load:queue
bin/rails db:schema:load:cable
```

If the host app also defines a separate `cache` database, load that with `bin/rails db:schema:load:cache`.

This repo's default development config does not define separate `cache`, `queue`, or `cable` databases, so those named schema-load tasks only exist in apps that add those database entries.
