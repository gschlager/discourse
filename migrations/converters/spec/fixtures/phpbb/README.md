# phpBB schema fixtures

Real phpBB *source* schemas (no data) used by the converter's retrieval-lint
spec (`spec/lib/migrations/converters/phpbb/source_spec.rb`), which runs every
`count_*`/`fetch_*` query against each version × backend to catch dialect/version
mismatches — e.g. Postgres 3.1+ dying on `UNIX_TIMESTAMP`, or an introspection
probe leaking across databases.

```
schemas/<version>/{mysql,postgres}.sql   # schema-only, table prefix phpbb_
```

The converter's schema surface is `{3.0, 3.1}` — `Database3_1` overrides only
`fetch_users` (the `user_website`/`user_from` → `profile_fields_data` relocation)
and `Database3_3` adds nothing — but we keep 3.2 and 3.3 too, to be safe.

## Why these are committed (not generated in CI)

A given phpBB release's schema is **immutable**, so it's a fixture, not something
to rebuild on every run. CI just loads these `.sql` files into MariaDB + Postgres
service containers — no PHP, no phpBB, no network in the test path.

## Regenerating (only when bumping supported versions)

phpBB stopped shipping per-DBMS schema SQL after 3.0; 3.1+ ship only `schema.json`
and materialize it through phpBB's own `db_tools` at install time. Worse, the
legacy drivers don't run on modern PHP (3.1 tops out at PHP 7.1), so generation
needs an **older PHP**, which `generate/` provides via Docker.

```
cd generate && ./generate.sh        # writes ../schemas/<version>/{mysql,postgres}.sql
```

`generate.sh` brings up throwaway MariaDB + Postgres, then for each version runs a
container pinned to a compatible PHP (3.0/3.1 → 7.1, 3.2 → 7.4, 3.3 → 8.x),
materializes the schema with phpBB's `db_tools`, and dumps it schema-only. See
`generate/README.md` for the per-version matrix.

> The Docker image only exists for generation, run by a maintainer when adding a
> version — never in CI or the normal test path.
