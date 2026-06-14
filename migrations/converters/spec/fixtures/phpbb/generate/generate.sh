#!/usr/bin/env bash
#
# Regenerates the committed phpBB schema fixtures (../schemas/<version>/*.sql).
# Run by a maintainer when adding/bumping a supported phpBB version — not in CI.
#
# For each version it spins up throwaway MariaDB + Postgres, then runs a
# generator container pinned to a PHP the release supports, downloads the phpBB
# tag, `composer install`s it, materializes the schema with phpBB's own
# `db_tools`, and dumps it schema-only. See ../README.md.
#
# Requires Docker (with registry access) and ~1GB of pulls.
set -euo pipefail
cd "$(dirname "$0")"

# version | release tag | PHP (legacy drivers cap the interpreter: 3.1 <= 7.1)
MATRIX=(
  "3.0|release-3.0.14|7.1"
  "3.1|release-3.1.12|7.1"
  "3.2|release-3.2.11|7.4"
  "3.3|release-3.3.14|8.1"
)

compose() { docker compose "$@"; }

# phpBB's Postgres schema needs the `varchar_ci` domain (+ its operators), which
# `db_tools` assumes exists; it's defined in 3.0's committed postgres_schema.sql
# preamble. Install just that preamble (no tables) before materializing.
pg_preamble() {
  local tag="$1"
  curl -fsSL "https://raw.githubusercontent.com/phpbb/phpbb/release-3.0.14/phpBB/install/schemas/postgres_schema.sql" \
    | awk '/CREATE TABLE/{exit} !/CREATE SEQUENCE/{print}'
  echo "COMMIT;"
}

generate_one() {
  local ver="$1" tag="$2" php="$3"
  echo ">>> phpBB ${ver} (${tag}) on PHP ${php}"
  mkdir -p "../schemas/${ver}"

  PHP_VERSION="${php}" compose up -d --build mariadb postgres
  PHP_VERSION="${php}" compose build generate

  # Fetch + composer install the phpBB source inside the generator container.
  PHP_VERSION="${php}" compose run --rm -T generate sh -euxc "
    rm -rf /work/phpbb && mkdir -p /work/phpbb
    curl -fsSL 'https://codeload.github.com/phpbb/phpbb/tar.gz/refs/tags/${tag}' \
      | tar xz -C /work/phpbb --strip-components=1
    cd /work/phpbb/phpBB
    composer install --no-dev --no-scripts --ignore-platform-reqs --no-progress
  "

  # Materialize into both engines, then dump schema-only.
  for engine in mysql postgres; do
    if [ "$engine" = "postgres" ]; then
      pg_preamble "$tag" | PHP_VERSION="${php}" compose exec -T postgres psql -U phpbb -d phpbb >/dev/null
    fi
    PHP_VERSION="${php}" compose run --rm -T \
      -e PHPBB_ROOT=/work/phpbb/phpBB \
      -e TARGET_ENGINE="$engine" \
      -e DB_NAME=phpbb -e DB_USER=phpbb -e DB_PASS=phpbb \
      -e DB_HOST="$([ "$engine" = mysql ] && echo mariadb || echo postgres)" \
      -e DB_PORT="$([ "$engine" = mysql ] && echo 3306 || echo 5432)" \
      generate php /work/materialize.php
  done

  dump_mysql "$ver"
  dump_postgres "$ver"
  PHP_VERSION="${php}" compose down -v
}

dump_mysql() {
  compose exec -T mariadb mariadb-dump --no-data --skip-comments --compact phpbb \
    >"../schemas/$1/mysql.sql"
}
dump_postgres() {
  compose exec -T postgres pg_dump --schema-only --no-owner --no-privileges phpbb \
    >"../schemas/$1/postgres.sql"
}

for row in "${MATRIX[@]}"; do
  IFS='|' read -r ver tag php <<<"$row"
  generate_one "$ver" "$tag" "$php"
done
echo "Done. Review and commit ../schemas/*/*.sql"
