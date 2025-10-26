# Atlas configuration for Docker environment
# Docs: https://atlasgo.io/

env "docker" {
  # Connect to the Postgres service on the Docker network
  url = "postgres://postgres:postgres@db:5432/ledger?sslmode=disable"

  # Optional dev database used by atlas for diff operations. Not required for apply, but helpful.
  dev = "docker://postgres/16/dev?search_path=public"

  migration {
    # Use Golang-Migrate style so we don't need an atlas.sum file
    dir    = "file://migrations"
    format = golang-migrate
  }
}
