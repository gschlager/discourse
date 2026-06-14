# Converter Architecture — A Model for Source Converters

A design for the phpBB3 converter that doubles as the template every future
source converter is cut from — and not only the SQL ones. It is grounded in the
existing migrations-tooling phpBB converter and the legacy
`script/import_scripts/phpbb3` importer: it keeps what those got right and fixes
the two things they got structurally wrong (dialect entangled with the version
class chain; driver quirks leaking into steps), while raising the abstraction so
the same template covers a vBulletin 5 rewrite or a NodeBB-on-MongoDB source.

> **Status.** This is a design, not a description of code that exists. Three of
> its load-bearing pieces are *not built yet* and are called out inline as
> prerequisites: IntermediateDB models for posts/permalinks/polls (see
> [Prerequisites](#prerequisites-what-must-exist-first)), the `Markbridge`
> content engine (see [Content layer](#content-layer)), and the source-side
> rework of the stateful `Messages` step (see
> [The Messages step](#the-messages-step-cross-item-state-must-move-to-the-source)).
> The step DSL below matches the realized `source`/`processor` split from
> #40816 — the prior prose used the older `process_item(item, stats)` API and
> has been corrected here.

## The one idea everything hangs on

**The stable seam is the Source's output contract, not the query mechanism.** A
Source promises the steps one thing: a lazy, parent-side stream of plain,
type-normalized row-hashes per entity, plus counts. Everything *below* that
promise — SQL, compatibility views, schema introspection, a Mongo aggregation
pipeline, a Redis key scan, an HTTP paginator — is free implementation. Two hard
questions ("a major version with breaking changes" and "what if the source is
MongoDB") are both *below-the-contract* decisions, which is precisely why neither
destabilizes the design.

## What the prior art teaches

Every claim below was verified against the current phpBB converter; file
references point at the code that exhibits the problem.

- **Version deltas are usually tiny.** Across phpBB 3.0 → 3.3 the only
  schema-shape change touching the core tables is `user_website`/`user_from`
  moving into `profile_fields_data` in 3.1 (`Database3_1#fetch_users` is the
  *only* override in the whole version chain; `Database3_3` is an empty
  subclass), plus the bcrypt `$2y$` → `$2a$` prefix swap (value-level, not
  version-level). Heavyweight version "detection" is unwarranted here.
- **Dialect, not version, broke the old design.** `Database3Postgres` is a
  subclass of `Database3` *only*, and the dispatch in `database.rb` wires it for
  3.0 alone — `3.1`/`3.2` resolve to `Database3_1` and `3.3` to `Database3_3`,
  both MySQL-flavored. A Postgres install on 3.1+ therefore dies on
  `UNIX_TIMESTAMP()` (`Database3_1#fetch_users`). Single inheritance cannot
  express `version × dialect`.
- **Dialect divergence is semantic, not textual.** The same query is written two
  ways: MySQL `CONCAT('[', GROUP_CONCAT(DISTINCT pt.user_id), ']')` building a
  fake-JSON string vs Postgres `json_agg(DISTINCT pt.user_id)` building real
  JSON; `JSON_ARRAYAGG(JSON_OBJECT(...))` vs `json_agg(jsonb_build_object(...))`;
  boolean vs `1/0`. Blind string-replace can't bridge these — a small set of
  *named substitution points* can.
- **Content leakage already reached the steps.** `steps/posts.rb` does
  `item[:uploads].is_a?(String) ? JSON.parse(...) : item[:uploads]` and
  `steps/messages.rb` repeats the identical guard for `item[:recipients]` —
  papering over a driver difference (MySQL returns aggregate JSON as a string,
  Postgres as parsed JSON) that belongs at the Source. There are two leak sites,
  not one.
- **Truthiness ambiguity rides along.** `fetch_posts` selects
  `pt.topic_id IS NOT NULL AS has_poll`; the step has to re-interpret a
  driver-dependent value instead of receiving a real boolean.

## Design decisions

1. **The Source's row contract is the stable seam.** Each entity is exposed as a
   count and a lazy stream of plain, symbol-keyed, type-normalized hashes. The
   key set a step consumes is the contract; the retrieval mechanism is
   implementation and may differ per source.
2. **Source access is parent-process only.** The Source role enumerates; workers
   receive plain hashes plus static config and run pure transforms. No worker
   holds a handle to the source store — SQL, Mongo, or otherwise. This is already
   enforced structurally by the `source`/`processor` split (#40816): the roles
   are separate objects, so a processor that reaches for source state raises a
   `NameError` instead of reading a stale fork snapshot.
3. **Type normalization is part of the contract.** Booleans → `true/false`, JSON
   → parsed Ruby, integers → `Integer`, `NULL` → `nil`. Steps never see store or
   driver quirks. Normalized values must also be serializable across the worker
   IPC wire contract (pinned in b4f7b066) — parsed hashes/arrays and `Integer`s
   are; build any `Time` objects worker-side, as the steps already do with
   `Time.at(...)`.
4. **SQL is a *family*, not the base.** Connection + dialect + views +
   introspection form a toolkit the SQL Source family uses. Non-SQL sources
   implement the same interface with their own retrieval and ignore the toolkit
   entirely.
5. **Version drift is normalized in place below a topology threshold, and split
   above it.** Column/join-level drift → capability object or compatibility
   views inside one Source. Topology-level drift → a separate Source
   implementation behind the same interface.
6. **Content format is sniffed per row** (`<r>`/`<t>` ⇒ XML, else legacy), not
   inferred from version. The legacy importer decides XML-vs-BBCode from the
   version string, which misfires on content authored before an in-place
   upgrade; per-row sniffing is robust to mixed content. Markbridge is the single
   conversion engine; the converter owns only a source-specific legacy
   pre-clean.
7. **No backward compatibility.** The existing phpBB converter is replaced
   wholesale; there is one consumer and it migrates immediately.

## Prerequisites: what must exist first

The step sketches below write to `IntermediateDB::Post`, `IntermediateDB::Permalink`,
and `IntermediateDB::Poll`/`PollOption`/`PollVote`. **None of these models exist
today.** The current converter writes posts and permalinks through an older
output API (`output_db.insert_post` / `Models.post` / `insert_permalink`), and in
the IntermediateDB schema those tables are *not modeled*:

- `permalinks` is listed in
  `migrations/tooling/config/schema/intermediate_db/ignored.rb`.
- there is no `tables/posts.rb`, `tables/polls.rb`, `tables/poll_options.rb`, or
  `tables/poll_votes.rb` under
  `migrations/tooling/config/schema/intermediate_db/tables/` — only `topics.rb`.

So before any of the post/poll/permalink steps can run, the IntermediateDB
schema has to gain those tables and regenerate its models:

1. Remove `:permalinks` (and the poll tables, if ignored) from `ignored.rb`.
2. Author `tables/posts.rb`, `tables/permalinks.rb`, `tables/polls.rb`,
   `tables/poll_options.rb`, `tables/poll_votes.rb` with the schema DSL (see
   `migrations/docs/schema-configuration.md`; `disco schema add TABLE`
   scaffolds one).
3. `disco schema generate` to emit the SQL schema and the
   `Migrations::Database::IntermediateDB::{Post,Permalink,Poll,...}` models.
4. `disco check` to confirm config and database are in sync.

This is framework work that gates the converter, and it sequences first.

## Layered architecture

The boundary that makes this a model is *interface vs implementation*, not
*framework vs converter*.

| Layer                                            | Home                                  | Scope                              |
|--------------------------------------------------|---------------------------------------|------------------------------------|
| **Source interface** (row contract)              | framework                             | Universal — every source           |
| Worker / Step (Source/Processor split)           | `migrations-core`                     | Universal                          |
| IntermediateDB, coverage, test harness           | framework                             | Universal                          |
| **SQL Source toolkit** (connection, dialect, views, introspection) | framework            | SQL source *family* only           |
| Source implementation                            | `converters/<x>/source/`              | Per source (SQL toolkit *or* own)  |
| Content                                          | `converters/<x>/content/`             | Per source markup                  |
| Steps                                            | `converters/<x>/steps/`               | Per source mapping                 |

A SQL converter (phpBB, vBulletin, XenForo, IPB, SMF, Flarum, source-Discourse)
implements `source/` on top of the toolkit. A non-SQL converter (NodeBB on Mongo
or Redis) implements `source/` against the same interface with its own retrieval.
Both inherit the worker machinery, IntermediateDB, and the contract above them.

### The data-flow invariant

```
        PARENT PROCESS                       │   FORKED / THREADED WORKERS
        (Source role)                        │   (Processor role)
                                             │
  Source impl:                               │   setup: build Content engine,
    SQL stream │ Mongo cursor │ Redis scan   │          lookups, id helpers
        │  parent-side, type-normalized      │          (once per worker)
        ▼                                    │
  fetch_*  ──►  plain Ruby row-hashes  ──────┼─►  process(item):
  count_*       + static config (over IPC)   │      Markbridge convert (pure CPU)
                                             │      build + write IntermediateDB
        ▲                                    │
   the source store lives here only          │   no source handle here
```

Load-bearing properties:

- **Workers are pure.** They never open the source store, so worker count, fork
  vs thread, and serialization are all free. A future JRuby `ThreadWorker`
  (not built yet — only the fork-based `Worker`/`ParallelJob` exist today)
  becomes additive: no shared connection to make thread-safe.
- **The retrieval mechanism is entirely parent-side.** SQL driver, Mongo cursor,
  Redis scan, or HTTP paginator — all of it lives in the parent; the contract
  above it is identical.
- **Enumeration is lazy/streaming.** SQL streams (mysql2 streaming / pg cursor),
  Mongo yields from a cursor, an API yields pages — all `fetch_*` as a lazy
  stream. For sources too large to stream cleanly across IPC, keyset pagination
  is the fallback. The old converter's unbounded `SELECT … ORDER BY post_id` is a
  memory hazard and is not carried forward.

## Directory layout

Framework:

```
migrations-converters/lib/migrations/converter/
├── source.rb                  # Source interface / row-contract (storage-agnostic)
└── source/
    └── sql/                   # toolkit for the SQL Source family (opt-in)
        ├── connection.rb      # streaming enumeration + type-normalization contract
        ├── mysql.rb           # mysql2 adapter
        ├── postgres.rb        # pg adapter
        ├── dialect.rb         # named SQL fragments, one instance per backend
        └── introspector.rb    # column/table existence probes (capabilities, views)
```

phpBB converter (SQL family, below the topology threshold ⇒ one Source):

```
converters/phpbb/
├── converter.rb               # registration, setup, step list, step_args
├── settings.yml
├── source/
│   ├── source.rb              # one Phpbb::Source; capability-driven seams
│   └── capabilities.rb        # probes the handful of version-variable columns
├── content/
│   ├── content.rb             # format sniff + route to Markbridge
│   └── legacy_cleaner.rb      # phpBB-specific pre-clean (only what Markbridge lacks)
├── steps/
│   ├── users.rb  posts.rb  topics.rb  categories.rb  groups.rb
│   ├── group_members.rb  messages.rb  permalinks.rb  anonymous_users.rb
│   └── polls/{polls,poll_options,poll_votes}.rb
└── spec/{source,content,steps}/
```

A major-jump converter splits the implementation instead of the files-per-minor:
`converters/vbulletin/source/` would carry `vb4_source.rb` and `vb5_source.rb`
(vB5 was a ground-up rewrite — different topology), both behind the same
interface, selected at setup. The steps never know which.

## Source interface

The contract, in full, is small:

```ruby
# Every Source — SQL or not — provides, per entity:
#   count_<entity>            -> Integer
#   fetch_<entity>            -> lazy Enumerator of normalized row-hashes
#
# Row-hashes are plain, symbol-keyed, with normalized types (booleans, parsed
# JSON, integers, nil). The key set fetch_<entity> yields is the contract the
# matching step consumes — and it is lintable (step's read keys ⊆ provided keys),
# regardless of storage.
```

### Below the threshold: phpBB as a SQL Source with capability seams

phpBB's drift is column/join-level, so it is one `Phpbb::Source`. Version is *not*
a class axis and *not* a set of files — the handful of variable spots are probed
once and resolved through named seams. (Views are the heavier alternative within
the SQL toolkit; for one delta, a capability object is proportionate.)

```ruby
module Phpbb
  class Source
    include Migrations::Converter::Source::SQL   # connection + dialect helpers

    def initialize(connection, prefix)
      @c, @prefix = connection, prefix
      @caps = Capabilities.detect(connection, prefix)   # probe the variable columns once
    end

    def count_users = @c.scalar("SELECT COUNT(*) FROM #{@prefix}users WHERE user_type <> 2")

    def fetch_users
      @c.stream(<<~SQL)
        SELECT u.user_id, u.user_email, u.username, u.user_password,
               u.user_regdate, u.user_lastvisit, u.user_ip, u.user_type,
               u.user_inactive_reason, g.group_name,
               b.ban_start, b.ban_end, b.ban_reason, u.user_posts,
               #{@caps.user_website_expr}  AS user_website,
               #{@caps.user_location_expr} AS user_from,
               u.user_birthday, u.user_avatar_type, u.user_avatar
        FROM #{@prefix}users u
          LEFT JOIN #{@prefix}groups g ON g.group_id = u.group_id
          #{@caps.profile_fields_join}
          LEFT JOIN #{@prefix}banlist b ON (
            u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
            (b.ban_end = 0 OR b.ban_end >= #{dialect.epoch_now})
          )
        WHERE u.user_type <> 2
        ORDER BY u.user_id
      SQL
    end

    # ... fetch_posts / fetch_messages / count_* — authored once, with
    #     dialect.json_array_agg(...) at any backend-divergent spot.
  end
end
```

```ruby
module Phpbb
  class Capabilities
    # Targeted introspection: probe only the known-variable columns, not the schema
    # at large. The version string is logged, never branched on for schema shape.
    def self.detect(c, prefix)
      relocated = !c.column_exists?("#{prefix}users", "user_website")
      new(
        user_website_expr:  relocated ? "f.pf_phpbb_website"  : "u.user_website",
        user_location_expr: relocated ? "f.pf_phpbb_location" : "u.user_from",
        profile_fields_join: relocated ?
          "LEFT JOIN #{prefix}profile_fields_data f ON u.user_id = f.user_id" : "",
      )
    end
  end
end
```

This is the answer to "no more files per version": one Source, capabilities from
reality, robust to in-place upgrades and lightly-customized schemas. It also
closes the silent-Postgres bug — the dispatch picks a dialect, not a
version-keyed class, so `version × dialect` no longer has gaps. Dispatch in
`converter.rb#setup` just opens the connection and constructs `Phpbb::Source`.

### Above the threshold, or off SQL entirely: a separate implementation

When the difference is *topology-level* (entities split/merged, relationships
restructured, identity re-keyed), or the store isn't relational at all, you write
a different Source against the same contract. NodeBB ships on MongoDB; the Source
runs aggregation/`find` cursors and maps documents to the agreed row-hashes:

```ruby
module Nodebb
  class MongoSource              # same interface; ignores the SQL toolkit
    def initialize(mongo) = @db = mongo

    def count_posts = @db[:posts].count_documents({})

    def fetch_posts
      return enum_for(:fetch_posts) unless block_given?
      @db[:posts].find.sort(_key: 1).each do |doc|   # cursor streams in the parent
        yield normalize(doc)                          # document -> row-hash contract
      end
    end

    private

    def normalize(doc)
      { post_id:   doc["pid"],   topic_id:  doc["tid"],
        post_text: doc["content"], post_time: doc["timestamp"].to_i,
        # ... exactly the keys the Posts step reads
      }
    end
  end
end
```

MongoDB *has* views, but you'd still drive them through the Mongo driver and emit
documents — so it isn't "the views solution," it's a Mongo Source that happens to
use Mongo internals. Compatibility views generalize only *within* the SQL family,
as a normalizer for version drift; they are not the universal mechanism. The
clinching case is NodeBB's other backend, **Redis** — no query language at all: a
Redis Source `SCAN`s keys in the parent and maps them to the same row-hashes, and
the entire Processor / IPC / IntermediateDB / coverage stack above the contract
does not change a line. That is the proof that the interface, not SQL, is the
base.

## SQL Source toolkit — dialect

Part of the SQL family toolkit, unused by non-SQL sources. This is the
disciplined form of "write MySQL, transform for Postgres": one canonical query,
with the genuinely divergent constructs supplied as named methods rather than
regex-substituted after the fact — so the aggregation queries that defeat
string-replace are handled correctly.

```ruby
module Migrations::Converter::Source::SQL
  class Dialect
    class MySQL < Dialect
      def epoch_now = "UNIX_TIMESTAMP()"
      def json_array_agg(expr) = "JSON_ARRAYAGG(#{expr})"
      def json_object(pairs)   = "JSON_OBJECT(#{pairs})"
      def id_array_agg(expr)   = "CONCAT('[', GROUP_CONCAT(DISTINCT #{expr}), ']')"
      def quote_ident(name)    = "`#{name}`"
    end

    class Postgres < Dialect
      def epoch_now = "EXTRACT(EPOCH FROM NOW())::bigint"
      def json_array_agg(expr) = "json_agg(#{expr})"
      def json_object(pairs)   = "jsonb_build_object(#{pairs})"
      def id_array_agg(expr)   = "json_agg(DISTINCT #{expr})"
      def quote_ident(name)    = %("#{name}")
    end
  end
end
```

The set is small by design — `epoch_now`, JSON aggregation, id-array aggregation,
identifier quoting cover every divergence in the real phpBB queries (the existing
`Database3` / `Database3Postgres` pair differs in exactly these spots and nothing
else). Type normalization closes the loop: because `id_array_agg` yields a
`"[1,2,3]"` string on MySQL and a JSON array on Postgres, the **connection**
normalizes JSON and aggregate columns to parsed Ruby before the row leaves the
parent, so the step receives `item[:recipients] == [1, 2, 3]` either way — and
neither `posts.rb` nor `messages.rb` needs its `is_a?(String)` guard anymore.

> The bcrypt `$2y$` → `$2a$` swap is value-level, but the current converter does
> it inside the SQL (`CASE WHEN user_password LIKE '$2y$%' …` with MySQL
> `CONCAT`/`SUBSTRING`). That reintroduces a dialect-specific construct into a
> query the dialect layer is meant to keep neutral, so it moves out of SQL into a
> normalizer (or the Users step) and is applied to the plain string after the row
> crosses the contract.

## Content layer

Markbridge is the single engine; the converter owns routing and a source-specific
legacy pre-clean.

> **Dependency.** `Markbridge` does not exist yet. Today the converter carries a
> forked BBCode/XML parser (`lib/phpbb_parser.rb`, `lib/bbcode/xml_to_markdown.rb`,
> `lib/bbcode/markdown_node.rb`). The plan is to delete those once Markbridge
> lands; until then the forked `PhpbbParser` is the interim engine behind the same
> `Content#to_markdown` facade, so the steps don't change when the engine is
> swapped.

```ruby
module Phpbb
  class Content
    def initialize(smilies:, attachment_resolver:, site_url:)
      @cleaner = LegacyCleaner.new(smilies:, attachment_resolver:)
      @site_url = site_url
    end

    def to_markdown(post_text, bbcode_uid:, uploads: nil)
      if xml?(post_text)
        Markbridge.textformatter_xml_to_markdown(post_text)
      else
        Markbridge.bbcode_to_markdown(@cleaner.call(post_text, bbcode_uid:, uploads:))
      end
    end

    private

    # s9e stores the parsed representation rooted at <r> (rich) or <t> (plain).
    def xml?(text) = text.start_with?("<r>", "<t>", "<r ", "<t ")
  end
end
```

`LegacyCleaner` ports the importer's `text_processor.rb` / `smiley_processor.rb`
regexes — uid strip (`/:(?:\w{5,8})\]/`), `<!-- s … -->` smilies, `<!-- m -->` /
`<!-- l -->` links, `[list]…[/list:u]` / `[*]…[/*:m]`, `[attachment=N]…` — but
**only the subset Markbridge's BBCode parser does not already cover**. The
importer's regex set is the conformance corpus: each pattern is a spec test fed
through Markbridge; whatever passes is deleted from the cleaner. Smilies and
attachment filenames are injected as plain lookups (built once in worker `setup`),
never DB calls — keeping the Processor pure.

## Step layer

Each step splits onto the Source/Processor API. `Posts` is representative —
attachments, content conversion, polls, permalinks in one. Note the step is
identical whether the Source behind it is SQL or Mongo; it only reads the row
contract.

The DSL is the one realized in #40816: a `source` block (parent process:
`items`, `max_progress`), a `processor` block (per worker: a `setup` *method*
that runs once after the fork, and `process(item)` for each item), and a
`helpers` block mixed into both. Per-worker collaborators are built in `setup`,
never in a constructor; warnings/errors are reported through the processor's
`tracker`, not a `stats` argument. Custom collaborators reach a role only if it
declares a matching `attr_accessor` — `assign_attributes` silently drops args
with no setter, so the accessors below are load-bearing, not decoration.

```ruby
module Phpbb
  class Posts < Conversion::ProgressStep
    run_in_parallel true        # process is CPU-bound (Markbridge) → fork it

    source do                   # PARENT: enumerate, no transformation
      attr_accessor :source_db

      def max_progress = source_db.count_posts
      def items        = source_db.fetch_posts   # streaming
    end

    processor do                # WORKER: pure transform + IntermediateDB write
      attr_accessor :phpbb_config   # `settings` is already provided by the base role

      def setup                 # once per worker after fork/thread start
        @content =
          Phpbb::Content.new(
            smilies: phpbb_config[:smilies],
            attachment_resolver: AttachmentResolver.new(phpbb_config[:attachment_path]),
            site_url: settings[:site_url],
          )
      end

      def process(item)
        uploads = build_uploads(item[:uploads], item[:poster_id])   # already parsed Ruby
        raw = @content.to_markdown(item[:post_text], bbcode_uid: item[:bbcode_uid], uploads:)
        raw = append_poll_placeholder(raw, item) if item[:has_poll]  # already boolean

        IntermediateDB::Post.create(
          original_id: item[:post_id],
          topic_id:    item[:topic_id],
          created_at:  Time.at(item[:post_time]),
          raw:         raw,
          user_id:     author_id(item),
          # ... every IntermediateDB Post column acknowledged; unavailable ⇒ column: nil
        )
        IntermediateDB::Permalink.create(
          url: "#{settings[:url_prefix]}viewtopic.php?p=#{item[:post_id]}",
          post_id: item[:post_id],
        )
      rescue SomeExpectedError => e
        tracker.log_warning("Could not convert post #{item[:post_id]}", exception: e)
      end
    end

    helpers do                  # pure, stateless, mixed into both roles
      def author_id(item)
        item[:post_username].present? ? IdGenerator.short_id(item[:post_username]) : item[:poster_id]
      end
    end
  end
end
```

The converter wires the custom collaborators through `step_args`:

```ruby
module Phpbb
  class Converter < BaseConverter
    def setup
      @source = Phpbb::Source.create(settings[:database])   # connection + dialect chosen here
      @phpbb_config = @source.fetch_config_values
    end

    def step_args(_step)
      { settings: settings[:import], source_db: @source, phpbb_config: @phpbb_config }
    end
  end
end
```

What vanished versus the prior art: no `item[:uploads].is_a?(String)` guard
(normalized at the Source), no `IS NOT NULL` truthiness ambiguity (`has_poll` is a
real boolean), no DB calls inside `process`, and no `process_item(item, stats)`
state smuggled across the fork. The Processor is a pure function of
`(item, static config)`.

### The Messages step: cross-item state must move to the Source

The current `Messages` step is `self.parallel = false` and keeps a
`@conversation_map` hash that it mutates **across items**, grouping phpBB private
messages that share a normalized subject + participant set into a single Discourse
PM topic. That pattern is exactly what the Source/Processor split forbids: a
processor instance is per-worker and per-item, so accumulating a map inside
`process(item)` either races (parallel) or is structurally unavailable. There is
no in-processor port of it.

The grouping has to move below the contract, into the Source, in one of two ways:

1. **Pre-group in the query.** Have `fetch_message_topics` emit one row per
   *conversation* (subject + sorted participants as the key, computed in SQL) and
   `fetch_messages` emit the posts, each already carrying its conversation key.
   The step then has two pure steps (`MessageTopics`, `Messages`) and no
   cross-item state. This is the preferred shape — it keeps both steps
   parallelizable.
2. **Group in the parent, lazily.** If the SQL is impractical, the Source builds
   the conversation→topic-id map as it streams (parent-side, single-threaded
   enumeration is fine) and stamps each yielded row with its `topic_id`. The step
   stays pure; the state lives where state is allowed.

Either way the dedup logic leaves the step. The design's rule — *steps are pure,
enumeration owns ordering and grouping* — is what makes this fall out cleanly;
the old step only worked because it ran serially.

## Testing

Mapped onto the established converter-testing pattern:

1. **Logic tests** — `process(item)` against a real in-memory SQLite
   IntermediateDB built from the generated schema, driven by plain item hashes.
   Trivial because the Processor is pure and storage-agnostic.
2. **Contract lint (universal)** — assert every key a step reads is in the set the
   Source yields. This is *new* analyzer work, not a free reuse of the existing
   IntermediateDB coverage tool (which only inspects write-side
   `IntermediateDB::X.create` keyword args). Statically deriving "the keys a
   Source yields" from a `SELECT` (aliases, `*`, computed columns) or a Mongo
   `normalize` hash is partial in the general case; treat it as best-effort over
   the common patterns, with an explicit allowlist escape hatch.
3. **Retrieval lint (SQL family)** — run every `fetch_*`/`count_*` against the
   *source* DDL, no data, across the grid `{3.0, 3.1, 3.3} × {mysql, postgres}`.
   The cheap test that would have caught "Postgres only wired for 3.0." Non-SQL
   sources lint their retrieval against fixtures instead.
4. **Content conformance** — the importer-regex corpus through `Content`, plus
   Bridgekeeper similarity gating on `raw` → cooked output.

## Open questions

- **Anonymous users.** `fetch_users` filters `user_type <> 2` everywhere while a
  separate `anonymous_users` step reconstructs guest posters from
  `posts.post_username`. Confirm that split survives the Source rework (it should
  — they're two entities) and that `author_id` stays the single place that maps a
  guest name to an id.
- **Index creation.** The current `Index` step issues `CREATE INDEX` on the
  *source* database for performance. Decide whether that belongs in the Source's
  setup (it's parent-side, source-touching) rather than as a step.
- **bcrypt normalization home.** Users step vs a connection-level value
  normalizer — pick one and apply it after the row crosses the contract.
