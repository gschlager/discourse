#!/usr/bin/env bash
#
# Regenerates the committed phpBB schema fixtures (../schemas/<version>/*.sql).
# Run by a maintainer when adding/bumping a supported phpBB version — not in CI.
#
# Spins up throwaway MariaDB + Postgres, populates a phpBB schema into each, and
# dumps it schema-only. 3.0 ships static schema SQL (it predates migrations and
# composer); 3.1+ are materialized from their migrations with phpBB's own
# `db_tools`, which needs an older PHP — hence the per-version container. See
# ../README.md.
#
# Requires Docker (with registry access) and ~1GB of pulls.
set -euo pipefail
cd "$(dirname "$0")"

RAW="https://raw.githubusercontent.com/phpbb/phpbb"

# version | release tag | PHP (legacy drivers cap the interpreter: 3.1 <= 7.1).
# Pinned to the final release of each EOL branch (3.0/3.1/3.2) and the latest
# 3.3; bump these when regenerating against a newer phpBB.
MATRIX=(
  "3.0|release-3.0.14|7.1"
  "3.1|release-3.1.12|7.1"
  "3.2|release-3.2.11|7.4"
  "3.3|release-3.3.17|8.1"
)

compose() { PHP_VERSION="${PHP_VERSION:-7.4}" docker compose "$@"; }

# Force TCP (-h127.0.0.1) on the MariaDB client: MARIADB_USER is created as
# phpbb@'%', which a socket connection (phpbb@'localhost') doesn't match.
mysql_cli() { compose exec -T mariadb mariadb -h127.0.0.1 -uphpbb -pphpbb phpbb; }
pg_cli() { compose exec -T postgres psql -q -U phpbb -d phpbb; }

# phpBB's Postgres schema needs the `varchar_ci` domain (+ operators), which
# `db_tools` assumes exists; it's defined in 3.0's committed postgres_schema.sql
# preamble. Emit just that preamble (everything before the first CREATE TABLE,
# minus the sequences). The awk reads the whole input rather than `exit`ing early,
# so it can't close the pipe mid-write and trip SIGPIPE under `pipefail`.
pg_preamble_sql() {
  curl -fsSL "${RAW}/release-3.0.14/phpBB/install/schemas/postgres_schema.sql" \
    | awk '/CREATE TABLE/{stop = 1} !stop && !/CREATE SEQUENCE/{print}'
  echo "COMMIT;"
}

wait_for_dbs() {
  echo "waiting for databases..."
  until compose exec -T postgres pg_isready -U phpbb -q; do sleep 1; done
  until compose exec -T mariadb mariadb-admin -h127.0.0.1 -uphpbb -pphpbb ping --silent 2>/dev/null; do sleep 1; done
}

populate_3_0() {
  local tag="$1" base="${RAW}/${1}/phpBB/install/schemas"
  curl -fsSL "${base}/mysql_41_schema.sql" | mysql_cli
  curl -fsSL "${base}/postgres_schema.sql" | pg_cli >/dev/null
}

populate_materialized() {
  local tag="$1"
  compose build generate
  pg_preamble_sql | pg_cli >/dev/null

  # Download, composer install, and materialize both engines in ONE container
  # (each `compose run` is ephemeral, so it must all happen together).
  compose run --rm -T generate sh -euxc "
    curl -fsSL 'https://codeload.github.com/phpbb/phpbb/tar.gz/refs/tags/${tag}' | tar xz -C /tmp
    src=/tmp/phpbb-${tag}/phpBB
    (cd \"\$src\" && composer install --no-dev --no-scripts --ignore-platform-reqs --no-progress)
    for engine in mysql postgres; do
      if [ \"\$engine\" = mysql ]; then host=mariadb port=3306; else host=postgres port=5432; fi
      PHPBB_ROOT=\"\$src\" TARGET_ENGINE=\"\$engine\" DB_HOST=\"\$host\" DB_PORT=\"\$port\" \
        DB_NAME=phpbb DB_USER=phpbb DB_PASS=phpbb php /work/materialize.php
    done
  "
}

generate_one() {
  local ver="$1" tag="$2"
  echo ">>> phpBB ${ver} (${tag}) on PHP ${PHP_VERSION}"
  mkdir -p "../schemas/${ver}"

  compose down -v >/dev/null 2>&1 || true # clean slate, in case a prior run was interrupted
  compose up -d --build mariadb postgres
  wait_for_dbs

  if [ "$ver" = "3.0" ]; then
    populate_3_0 "$tag"
  else
    populate_materialized "$tag"
  fi

  compose exec -T mariadb mariadb-dump -h127.0.0.1 --no-data --skip-comments --compact -uphpbb -pphpbb phpbb \
    >"../schemas/${ver}/mysql.sql"
  compose exec -T postgres pg_dump --schema-only --no-owner --no-privileges -U phpbb phpbb \
    >"../schemas/${ver}/postgres.sql"

  compose down -v
}

for row in "${MATRIX[@]}"; do
  IFS='|' read -r ver tag PHP_VERSION <<<"$row"
  export PHP_VERSION
  generate_one "$ver" "$tag"
done
echo "Done. Review and commit ../schemas/*/*.sql"
