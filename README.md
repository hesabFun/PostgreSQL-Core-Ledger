Project: PostgreSQL 16 + Atlas (DB migrations) + pgAdmin via Docker Compose

Overview
This project provides a ready-to-run local development stack with:
- PostgreSQL 16 as the database
- Atlas as the database migration tool
- pgAdmin 4 as the database management UI
- Docker Compose to orchestrate all services and run migrations automatically on startup

Repository structure
- docker-compose.yml — Orchestrates Postgres, Atlas (migrations), and pgAdmin
- atlas.hcl — Atlas configuration (connection URL and migration directory)
- migrations/ — Database migration files (Golang-Migrate format)
    - 20251023145101_init.up.sql — Example migration that creates a users table
    - 20251023145101_init.down.sql — Rollback for the example migration
- .env — Default environment variables (can be customized)
- README.md — This documentation

Prerequisites
- Docker Desktop (or Docker Engine + Docker Compose) installed and running

Quick start
1) Configure environment variables (optional)
- Edit .env to adjust credentials and ports if needed.

2) Start the stack
- Run: docker compose up --build
- What will happen:
    - Postgres 16 starts and becomes healthy.
    - The migrate service runs "atlas migrate apply --env docker" one time and exits after applying migrations.
    - pgAdmin becomes available on http://localhost:5050 (default).

3) Access pgAdmin
- Open http://localhost:5050 in your browser.
- Login with:
    - Email: admin@example.com (default)
    - Password: admin (default)
- Add a new Server in pgAdmin:
    - General
        - Name: Local Postgres (any name you like)
    - Connection
        - Host name/address: db
        - Port: 5432 (or your POSTGRES_PORT if changed)
        - Maintenance database: app (or your POSTGRES_DB)
        - Username: postgres (or your POSTGRES_USER)
        - Password: postgres (or your POSTGRES_PASSWORD)
- Save and connect. You should see the app database and (after first run) a users table under Schemas -> public -> Tables.

Managing migrations with Atlas
- Migration format: golang-migrate style (file names like 20250101120000_add_table.up.sql)
- Files live in: migrations/

Create a new migration file
- You can author SQL directly inside migrations/*.up.sql and optional *.down.sql.
- Example file names:
    - migrations/20251101090000_add_products.up.sql
    - migrations/20251101090000_add_products.down.sql

Apply migrations (re-run manually)
- The migrate service runs automatically on docker compose up. If you add new migration files or see checksum errors, run:
    - docker compose run --rm migrate migrate hash --env docker
    - docker compose run --rm migrate migrate apply --env docker

See migration status
- docker compose run --rm migrate atlas migrate status --env docker

Roll back last migration (down)
- docker compose run --rm migrate atlas migrate down --env docker -- 1
    - The trailing "-- 1" tells Atlas to revert one migration. Adjust as needed.

Stop the stack
- Press Ctrl+C in the terminal where docker compose up is running, then:
    - docker compose down

Persisted data and volumes
- Postgres data is persisted in the db_data Docker volume.
- pgAdmin state is persisted in the pgadmin_data Docker volume.
- To remove containers and volumes (CAUTION: destroys your DB data):
    - docker compose down -v

Configuration reference
- .env variables (defaults shown):
    - POSTGRES_USER=postgres
    - POSTGRES_PASSWORD=postgres
    - POSTGRES_DB=app
    - POSTGRES_PORT=5432
    - PGADMIN_DEFAULT_EMAIL=admin@example.com
    - PGADMIN_DEFAULT_PASSWORD=admin
    - PGADMIN_PORT=5050
    - ATLAS_LOG_FORMAT=cli

Notes and tips
- If you change credentials or DB name in .env, pgAdmin connection settings must match.
- The migrate service depends on the db healthcheck, ensuring migrations only run after Postgres is ready.
- The Atlas configuration (atlas.hcl) is set to use the Docker network host name db to connect to Postgres.
- For schema diff and declarative workflows, see Atlas docs: https://atlasgo.io/

Troubleshooting
- Port already in use:
    - Change POSTGRES_PORT or PGADMIN_PORT in .env and re-run docker compose up.
- Authentication failure in pgAdmin:
    - Ensure your pgAdmin connection user/password match the values in .env for Postgres.
- Migrations didn’t run:
    - Check logs of the migrate service: docker compose logs migrate
    - Run manually: docker compose run --rm migrate
- Checksum error about atlas.sum:
    - If you see "You have a checksum error in your migration directory" or "checksum file not found", just run the migrate service to generate checksums and apply: docker compose run --rm migrate
- Reset everything (DANGER: deletes data):
    - docker compose down -v && docker compose up --build

License
- This sample is provided as-is. Use freely for learning or as a starting point for your projects.
