# phpBB fixture generator

Regenerates `../schemas/<version>/{mysql,postgres}.sql` from phpBB's own schema
definitions, using phpBB's `db_tools` so the DDL is exactly what phpBB installs.
Run only when adding/bumping a supported version; the output is committed.

```
./generate.sh          # needs Docker with registry access (~1GB of pulls)
```

## Why Docker / older PHP

phpBB stopped shipping per-DBMS schema SQL after 3.0 (3.1+ ship only
`schema.json`, materialized by `db_tools` at install). Its legacy DB drivers
don't run on modern PHP — phpBB 3.1's `mysqli` driver fails on PHP 8.x — so each
release is materialized under a PHP it supports:

| phpBB | release tag      | PHP |
|-------|------------------|-----|
| 3.0   | `release-3.0.14` | 7.1 |
| 3.1   | `release-3.1.12` | 7.1 |
| 3.2   | `release-3.2.11` | 7.4 |
| 3.3   | `release-3.3.14` | 8.1 |

`db_tools`' bootstrap also changed across versions (the `filesystem` namespace,
the `sqlite` driver name, and the `db_tools` factory); `materialize.php` detects
the right variant at runtime.

## Pipeline (per version)

1. Bring up throwaway MariaDB + Postgres (`docker-compose.yml`, tmpfs — no data
   kept).
2. In a PHP-pinned container: download the phpBB tag, `composer install`.
3. For Postgres, install phpBB's `varchar_ci` domain preamble (taken from 3.0's
   committed `postgres_schema.sql`, which `db_tools` assumes exists).
4. `materialize.php` builds the schema from the migrations and creates the tables
   via `db_tools`.
5. Dump schema-only (`mariadb-dump --no-data` / `pg_dump --schema-only`) into
   `../schemas/<version>/`.

## Status

The individual steps are validated against real phpBB sources (the
`create_schema_files.php` → `schema.json` → `db_tools` materialize flow produces
real 3.0/3.2/3.3 schemas). The Dockerized orchestration here packages them for
the older-PHP versions; run it in an environment with container-registry access
and review the diff before committing the regenerated fixtures.
