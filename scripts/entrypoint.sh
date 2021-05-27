#!/bin/bash
# Docker entrypoint script.

# Wait until Postgres is ready
while ! pg_isready -q -h db -p 5432 -U postgres
do
  echo "$(date) - waiting for database to start"
  sleep 2
done

mix deps.get
mix ecto.setup
cd assets && npm install && cd ..
mkdir -p storage/dev

exec iex -S mix phx.server