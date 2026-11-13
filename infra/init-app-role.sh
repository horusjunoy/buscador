#!/bin/sh
set -eu
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=ON_ERROR_STOP=1 --set=app_password="$APP_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE buscador_app LOGIN PASSWORD %L', :'app_password')
\gexec
GRANT CONNECT ON DATABASE buscador TO buscador_app;
GRANT USAGE ON SCHEMA public TO buscador_app;
SQL
