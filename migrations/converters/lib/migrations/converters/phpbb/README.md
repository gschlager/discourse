# phpBB converter

Converts a phpBB 3.x forum (MySQL or PostgreSQL) into the IntermediateDB that the
importer loads into Discourse.

> **Status: skeleton.** The structure, step list, and contracts are in place, but
> `Phpbb::Source` and every step's `process` still raise `NotImplementedError`.
> It is built to be filled in slice by slice.

## Layout

```
phpbb/
├── converter.rb          # registration, setup, step_args
├── settings.yml          # source DB connection + import options
├── source/
│   ├── source.rb         # Phpbb::Source — count_*/fetch_* row contract
│   └── capabilities.rb   # probes the version-variable columns
├── content/
│   ├── content.rb        # per-row format sniff -> Markbridge Content
│   └── legacy_cleaner.rb # phpBB pre-clean (only what Markbridge lacks)
└── steps/
    ├── users.rb anonymous_users.rb groups.rb group_members.rb
    ├── categories.rb topics.rb posts.rb messages.rb permalinks.rb
    └── polls/{polls,poll_options,poll_votes}.rb
```

## How it fits the framework

- The **Source** runs in the parent process and yields plain, type-normalized
  row-hashes; **processors** run in workers and are pure transforms — they never
  touch the source DB. See `migrations/docs/converter-architecture.md`.
- Post bodies convert through the shared `Migrations::Converters::Content`
  (Markbridge); deferred embeds use `EmbedBuffer` + `PostEmbedWriter`.
- Uploads (avatars, attachments) go through `Migrations::Converters::UploadCreator`.

## Filling it in

Each step and the Source carry `TODO` notes pointing at the legacy
`script/import_scripts/phpbb3` importer (the data mapping) and the design doc (the
architecture). Remaining framework prerequisites: the SQL Source toolkit and the
`permalinks` / `polls` / `poll_options` / `poll_votes` IntermediateDB tables.
