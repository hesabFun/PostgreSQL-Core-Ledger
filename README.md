# Multi Tenant Double Entry Accounting DB schema

## Overview
This project provides a ready-to-run local development stack with:
- PostgreSQL 18 as the database
- Atlas as the database migration tool
- pgAdmin 4 as the database management UI
- PgTap the unit test framework
- Docker Compose to orchestrate all services and run migrations automatically on startup

## Repository structure
- docker-compose.yml — Orchestrates Postgres, Atlas (migrations), and pgAdmin
- atlas.hcl — Atlas configuration (connection URL and migration directory)
- migrations/ — Database migration files (Golang-Migrate format)
    - 00_core_init_tables.sql — Initial migration that creates the core ledger tables
    - 01_create_tenant_function.sql — Function to create a new tenant
- PGTap/ — Database test files (pgTAP)
    - 00_core_tables_test.sql — Tests for the core ledger schema
- .env — Default environment variables (can be customized)
- README.md — This documentation

## Prerequisites
- Docker Desktop (or Docker Engine + Docker Compose) installed and running

## Quick start
1) Configure environment variables (optional)
- Edit .env to adjust credentials and ports if needed.

2) Start the stack
- Run: `docker compose up`
- What will happen:
    - Postgres 18 starts and becomes healthy.
    - The migrate service runs "atlas migrate apply" one time and exits after applying migrations.
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
        - Port: 5432 (or your PGPORT if changed)
        - Maintenance database: ledger (or your PGDATABASE)
        - Username: postgres (or your PGUSER)
        - Password: postgres (or your PGPASSWORD)
- Save and connect. You should see the ledger database and (after the first run) the core tables under Schemas -> public -> Tables.

## Managing migrations with Atlas
- Migration format: golang-migrate style (file names like 20250101120000_add_table.up.sql)
- Files live in: migrations/

## Create a new migration file
- You can author SQL directly inside migrations/*.up.sql and optional *.down.sql.
- Example file names:
    - migrations/00_core_init_tables.sql

## Apply migrations (re-run manually)
- The migrate service runs automatically on docker compose up. If you add new migration files or see checksum errors, run:
    - `docker compose run --rm migrate migrate hash`
    - `docker compose run --rm migrate migrate apply`

## See migration status
- `docker compose run --rm migrate migrate status`

## Roll back last migration (down)
- `docker compose run --rm migrate migrate down -- 1`
    - The trailing "-- 1" tells Atlas to revert one migration. Adjust as needed.

## Running Tests with pgTAP
- Tests are located in: PGTap/
- To run all tests:
    - `docker compose run --rm pgtap`
- This will:
    1. Ensure the database and migrations are ready.
    2. Install the pgtap extension (if not already present).
    3. Execute all .sql files in the PGTap/ directory using pg_prove.

## Stop the stack
- Press Ctrl+C in the terminal where docker compose up is running, then:
    - `docker compose down`

## Persisted data and volumes
- Postgres data is persisted in the db_data Docker volume.
- pgAdmin state is persisted in the pgadmin_data Docker volume.
- To remove containers and volumes (CAUTION: destroys your DB data):
    - `docker compose down -v`

## Configuration reference
- .env variables (defaults shown):
    - PGUSER=postgres
    - PGPASSWORD=postgres
    - PGDATABASE=ledger
    - PGPORT=5432
    - PGADMIN_DEFAULT_EMAIL=admin@example.com
    - PGADMIN_DEFAULT_PASSWORD=admin
    - PGADMIN_PORT=5050
    - ATLAS_LOG_FORMAT=cli

## Notes and tips
- If you change credentials or DB name in .env, pgAdmin connection settings must match.
- The migrate service depends on the db healthcheck, ensuring migrations only run after Postgres is ready.
- The Atlas configuration (atlas.hcl) is set to use the Docker network host name db to connect to Postgres.
- For schema diff and declarative workflows, see Atlas docs: https://atlasgo.io/

## Troubleshooting
- Port already in use:
    - Change PGPORT or PGADMIN_PORT in .env and re-run docker compose up.
- Authentication failure in pgAdmin:
    - Ensure your pgAdmin connection user/password matches the values in .env for Postgres.
- Update the atlas.sum file:
    - Run `docker compose run --rm migrate migrate hash` to generate checksums and apply:
- Migrations didn’t run:
    - Check logs of the migrate service: docker compose logs migrate
    - Run manually: `docker compose run --rm migrate`
- Checksum error about atlas.sum:
    - If you see "You have a checksum error in your migration directory" or "checksum file not found", just run the migrate service to generate checksums and apply: `docker compose run --rm migrate`
- Reset everything (DANGER: deletes data):
    - `docker compose down -v && docker compose up`

## TODO
- [x] Create a function to create a tenant
- [x] Create a function to create an account for a tenant
- [ ] Create a function to create a ledger
- [ ] Create a function to create a ledger entry
- [ ] Create a function to query ledger entries

## License
- This sample is provided as-is. Use freely for learning or as a starting point for your projects.
