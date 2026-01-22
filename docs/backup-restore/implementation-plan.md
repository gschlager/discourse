# Backup/Restore V2 Implementation Plan

## Approach

- **Start fresh** - v2 branch and main as inspiration only
- **Small PRs** - Max ~150 lines per PR, ideally smaller
- **Tests first** - Every PR includes tests
- **Incremental** - Each PR adds one working feature
- **CLI: Samovar** - Class-based, testable, good documentation

## Priority Order (from todos.md)

| Priority | Feature |
|----------|---------|
| HIGH | Gracefully handle database errors during restore |
| HIGH | Restoring uploads shouldn't fail |
| HIGH | Restore database without uploads (`--no-uploads`) |
| HIGH | Restore database without remapping (`--no-remap`) |
| MEDIUM | Streamlined CLI output |
| MEDIUM | Allow restore on version mismatch (`--force`) |
| MEDIUM | Download missing uploads |
| MEDIUM | Improve remapping of upload URLs |
| LOW | Autocorrect for unique index errors |
| LOW | Handle `migrate_to_new_scheme` failures |
| LOW | New backup archive format (v2) |

---

## Upload Pain Points

Uploads are the #1 source of restore failures. From team feedback (2022-2023):

**The core problem:**
> "Missing uploads should not abort restores, because it means we're producing unrestorable backups."
> — @Supermathie

> "46 missing uploads out of 253,100 posts = total failure. The restore would have failed even with 1 upload missing, seems overkill."
> — @cocococosti

> "76GB backups take hours to download, decompress, and restore DB, only to fail at the end due to upload validation."
> — @leonardo

**Specific issues:**

1. **Flawed `posts:missing_uploads` check** (used during restore)
   - Heuristic-based: looks for URLs that "look like uploads" in post HTML
   - Produces false positives (users can type URLs that match pattern)
   - David: "IMO we should probably just remove it"
   - This check should NOT be part of restore pipeline

2. **Inconsistent backup/restore behavior**
   - Backup succeeds even with missing uploads
   - Restore fails on ANY missing upload
   - Either backup should be stricter OR restore should be lenient (restore should be lenient)

3. **No way to skip upload validation**
   - Workarounds: `GIVE_UP=1`, modifying code, pausing restore
   - Need explicit `--skip-upload-validation` flag

4. **S3 deduplication** (addressed in PR #37261)
   - Secure uploads create duplicates (same `original_sha1`, different `sha1`)
   - Hardlink deduplication reduces backup size dramatically

5. **Performance**
   - Backup uses single-threaded gzip (conservative for live server)
   - Restore could use pigz (multi-threaded) for faster decompression

**Future considerations:**
- S3-to-S3 direct clone for migrations (no download/upload cycle)
- Multiple S3 buckets and other storage (Azure, GCS)

---

## Implementation Chunks

### Chunk 1: CLI Skeleton with Samovar
**~80-100 lines**

Create basic CLI structure with Samovar:
- `script/disco` entry point
- `Disco::Application` main command
- `Disco::Commands::Backup` subcommand (stub)
- `Disco::Commands::Restore` subcommand (stub)
- Version and help output

```ruby
# script/disco
#!/usr/bin/env ruby
require_relative "../lib/disco"
Disco::Application.call

# lib/disco.rb
require "samovar"
require_relative "disco/application"
require_relative "disco/commands/backup"
require_relative "disco/commands/restore"

# lib/disco/application.rb
module Disco
  class Application < Samovar::Command
    self.description = "Discourse backup and restore CLI"

    nested :command, {
      "backup" => Commands::Backup,
      "restore" => Commands::Restore,
    }, default: "help"

    def call
      @command.call
    end
  end
end
```

**Test:** Spec that verifies help output, version, command routing.

---

### Chunk 2: Logger Foundation
**~60-80 lines**

Simple logger that works for both CLI and background jobs:
- Logs to STDOUT (CLI) or MessageBus (background)
- Tracks warnings/errors
- Formats messages consistently

```ruby
# lib/disco/logger.rb
module Disco
  class Logger
    attr_reader :warnings, :errors

    def initialize(output: $stdout)
      @output = output
      @warnings = []
      @errors = []
    end

    def log(message)
      @output.puts message
    end

    def warn(message)
      @warnings << message
      log "WARNING: #{message}"
    end

    def error(message)
      @errors << message
      log "ERROR: #{message}"
    end

    def warnings? = @warnings.any?
    def errors? = @errors.any?
  end
end
```

**Test:** Spec for log, warn, error, tracking.

---

### Chunk 3: Restore Command - Basic Structure
**~60-80 lines**

Restore command with options parsing (no implementation yet):

```ruby
# lib/disco/commands/restore.rb
module Disco
  module Commands
    class Restore < Samovar::Command
      self.description = "Restore a backup"

      options do
        # What to restore
        option "--uploads-only", "Only restore uploads (DB already restored)"
        option "--no-uploads", "Skip restoring uploads"

        # How to restore
        option "--no-remap", "Skip URL remapping (restore DB as-is)"
        option "--no-download", "Don't try to download missing uploads"
        option "--skip-upload-validation", "Skip post upload validation"
        option "--force", "Restore even on version mismatch"
        option "-i/--interactive", "Interactive mode (pause on errors)"

        # Performance
        option "-j/--jobs <n>", "Parallel S3 upload/download threads (default: 4)", default: 4
      end

      one :filename, "Backup filename", required: true

      def call
        # TODO: Implementation
        puts "Would restore: #{filename}"
        puts "Options: #{@options}"
      end
    end
  end
end
```

**Test:** Spec for option parsing.

---

### Chunk 4: Database Configuration Helper
**~40-60 lines**

Extract database config into reusable module:

```ruby
# lib/disco/database.rb
module Disco
  class Database
    def self.configuration
      @configuration ||= begin
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        OpenStruct.new(
          host: config[:host],
          port: config[:port],
          database: config[:database],
          username: config[:username],
          password: config[:password]
        )
      end
    end

    def self.psql_env
      config = configuration
      env = {}
      env["PGPASSWORD"] = config.password if config.password.present?
      env["PGHOST"] = config.host if config.host.present?
      env["PGPORT"] = config.port.to_s if config.port.present?
      env["PGUSER"] = config.username if config.username.present?
      env["PGDATABASE"] = config.database
      env
    end
  end
end
```

**Test:** Spec with mocked ActiveRecord config.

---

### Chunk 5: SQL Statement Streamer (Core)
**~100-120 lines**

Read gzipped SQL dump, yield complete statements:

```ruby
# lib/disco/restore/sql_reader.rb
module Disco
  module Restore
    class SqlReader
      SKIP_PATTERNS = [
        /\ADROP SCHEMA/i,
        /\ACREATE SCHEMA/i,
        /\ACOMMENT ON SCHEMA/i,
        /\ACREATE EXTENSION/i,
        /\ACOMMENT ON EXTENSION/i,
        /\ASET default_table_access_method/i,
      ].freeze

      def initialize(path)
        @path = path
      end

      def each_statement
        return enum_for(:each_statement) unless block_given?

        buffer = +""

        open_stream do |io|
          io.each_line do |line|
            next if line.start_with?("--")
            next if line.strip.empty?

            buffer << line

            if statement_complete?(buffer)
              statement = buffer.strip
              buffer = +""
              next if skip_statement?(statement)
              yield statement
            end
          end
        end
      end

      private

      def open_stream(&block)
        if @path.end_with?(".gz")
          Zlib::GzipReader.open(@path, &block)
        else
          File.open(@path, "r", &block)
        end
      end

      def statement_complete?(buffer)
        buffer.strip.end_with?(";")
      end

      def skip_statement?(statement)
        SKIP_PATTERNS.any? { |pattern| statement.match?(pattern) }
      end
    end
  end
end
```

**Test:** Spec with fixture SQL files (plain and gzipped).

---

### Chunk 6: Psql Writer (Core)
**~80-100 lines**

Write statements to psql, capture errors:

```ruby
# lib/disco/restore/psql_writer.rb
module Disco
  module Restore
    class PsqlWriter
      attr_reader :last_error

      def initialize
        @env = Database.psql_env
      end

      def open
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(
          @env,
          "psql", "--quiet", "--no-psqlrc"
        )
        yield self
      ensure
        close
      end

      def write(statement)
        @stdin.puts(statement)
        @stdin.flush
        true
      rescue IOError => e
        @last_error = e.message
        false
      end

      def close
        @stdin&.close
        @stdout&.close
        @stderr&.close
        @wait_thread&.value
      end
    end
  end
end
```

**Test:** Spec with test database.

---

### Chunk 7: Error Handler - Parsing PostgreSQL Errors
**~60-80 lines**

Parse and categorize PostgreSQL error messages:

```ruby
# lib/disco/restore/error_parser.rb
module Disco
  module Restore
    class ErrorParser
      CATEGORIES = {
        /could not create unique index/i => :unique_violation,
        /duplicate key value violates unique constraint/i => :duplicate_key,
        /relation .+ already exists/i => :relation_exists,
        /extension .+ already exists/i => :extension_exists,
        /permission denied/i => :permission_denied,
      }.freeze

      Result = Struct.new(:category, :message, :detail, :skippable?, keyword_init: true)

      def parse(stderr_output)
        category = categorize(stderr_output)
        detail = extract_detail(stderr_output)

        Result.new(
          category: category,
          message: stderr_output,
          detail: detail,
          skippable?: skippable?(category)
        )
      end

      private

      def categorize(message)
        CATEGORIES.each do |pattern, category|
          return category if message.match?(pattern)
        end
        :unknown
      end

      def extract_detail(message)
        message[/DETAIL:\s*(.+)$/i, 1]
      end

      def skippable?(category)
        %i[extension_exists relation_exists].include?(category)
      end
    end
  end
end
```

**Test:** Spec with various PostgreSQL error formats.

---

### Chunk 8: Interactive Error Handler
**~80-100 lines**

Handle errors in interactive mode - pause, ask user:

```ruby
# lib/disco/restore/error_handler.rb
module Disco
  module Restore
    class ErrorHandler
      def initialize(logger:, interactive: false)
        @logger = logger
        @interactive = interactive
      end

      def handle(error, statement:)
        parsed = ErrorParser.new.parse(error)

        if parsed.skippable?
          @logger.warn "Skipping: #{parsed.message}"
          return :skip
        end

        if @interactive
          prompt_user(parsed, statement)
        else
          @logger.error parsed.message
          :abort
        end
      end

      private

      def prompt_user(parsed, statement)
        puts "\nDatabase restore paused!"
        puts "  ERROR: #{parsed.message}"
        puts "  DETAIL: #{parsed.detail}" if parsed.detail
        puts ""
        puts "What would you like to do?"
        puts "  [s] Skip this statement"
        puts "  [r] Retry"
        puts "  [a] Abort restore"
        print "> "

        case $stdin.gets&.strip&.downcase
        when "s" then :skip
        when "r" then :retry
        else :abort
        end
      end
    end
  end
end
```

**Test:** Spec with mocked stdin for interactive mode.

---

### Chunk 9: Database Restorer - Streaming Implementation
**~100-120 lines**

Tie together SqlReader, PsqlWriter, ErrorHandler:

```ruby
# lib/disco/restore/database_restorer.rb
module Disco
  module Restore
    class DatabaseRestorer
      def initialize(dump_path, logger:, interactive: false)
        @dump_path = dump_path
        @logger = logger
        @error_handler = ErrorHandler.new(logger: logger, interactive: interactive)
      end

      def restore
        @logger.log "Restoring database..."
        count = 0

        PsqlWriter.new.open do |psql|
          SqlReader.new(@dump_path).each_statement do |statement|
            result = execute_with_retry(psql, statement)
            return false if result == :abort

            count += 1
            print "." if count % 100 == 0
          end
        end

        @logger.log "\nRestored #{count} statements"
        true
      end

      private

      def execute_with_retry(psql, statement)
        loop do
          success = psql.write(statement)
          return :ok if success

          action = @error_handler.handle(psql.last_error, statement: statement)
          case action
          when :skip then return :ok
          when :abort then return :abort
          when :retry then next
          end
        end
      end
    end
  end
end
```

**Test:** Integration spec with test SQL dump.

---

### Chunk 10: Backup Extraction (v1 format)
**~60-80 lines**

Extract v1 backup archives:

```ruby
# lib/disco/restore/backup_extractor.rb
module Disco
  module Restore
    class BackupExtractor
      def initialize(backup_path, tmp_dir)
        @backup_path = backup_path
        @tmp_dir = tmp_dir
      end

      def extract
        FileUtils.mkdir_p(@tmp_dir)

        if @backup_path.end_with?(".sql.gz")
          # Plain SQL dump (no uploads)
          dump_path = File.join(@tmp_dir, "dump.sql.gz")
          FileUtils.cp(@backup_path, dump_path)
          { dump_path: dump_path, uploads_path: nil }
        else
          # Tar archive
          extract_tar
        end
      end

      private

      def extract_tar
        system("tar", "-xf", @backup_path, "-C", @tmp_dir)

        dump_path = Dir.glob(File.join(@tmp_dir, "*.sql.gz")).first ||
                    Dir.glob(File.join(@tmp_dir, "dump.sql.gz")).first
        uploads_path = File.join(@tmp_dir, "uploads")
        uploads_path = nil unless File.directory?(uploads_path)

        { dump_path: dump_path, uploads_path: uploads_path }
      end
    end
  end
end
```

**Test:** Spec with fixture backup files.

---

### Chunk 11: Restore Command - Full Implementation
**~80-100 lines**

Wire everything together:

```ruby
# lib/disco/commands/restore.rb (updated)
def call
  load_rails
  logger = Disco::Logger.new

  logger.log "Discourse Restore"
  logger.log "================="

  # Extract
  logger.log "[1/5] Extracting backup..."
  extractor = Restore::BackupExtractor.new(filename, tmp_directory)
  paths = extractor.extract

  # Uploads-only mode: skip DB restore, just restore uploads
  if @options[:uploads_only]
    return restore_uploads_only(paths, logger)
  end

  unless paths[:dump_path]
    logger.error "No database dump found in backup"
    return 1
  end

  # Restore DB
  logger.log "[2/5] Restoring database..."
  restorer = Restore::DatabaseRestorer.new(
    paths[:dump_path],
    logger: logger,
    interactive: @options[:interactive]
  )
  return 1 unless restorer.restore

  # Remap URLs (works for SQL-only backups too)
  if @options[:no_remap]
    logger.log "[3/5] Skipping URL remapping (--no-remap, DB restored as-is)"
  else
    logger.log "[3/5] Remapping URLs..."
    Restore::UrlRemapper.new(backup_metadata, logger: logger).remap
  end

  # Uploads
  if @options[:no_uploads]
    logger.log "[4/5] Skipping uploads (--no-uploads)"
    logger.log "    Run again with --uploads-only to restore uploads later"
  else
    logger.log "[4/5] Restoring uploads..."
    upload_restorer = Restore::UploadRestorer.new(
      paths[:uploads_path],
      logger: logger,
      skip_validation: @options[:skip_upload_validation],
      threads: @options[:jobs]
    )
    upload_restorer.restore
  end

  # Finalize
  logger.log "[5/5] Finalizing..."
  run_migrations
  clear_caches

  report_summary(logger)
  0
end

private

def restore_uploads_only(paths, logger)
  logger.log "Uploads-only mode (assuming DB already restored)"

  unless paths[:uploads_path]
    logger.error "No uploads found in backup"
    return 1
  end

  # Optional: remap URLs first if not already done
  unless @options[:no_remap]
    logger.log "[1/2] Remapping URLs..."
    Restore::UrlRemapper.new(backup_metadata, logger: logger).remap
  end

  logger.log "[2/2] Restoring uploads..."
  upload_restorer = Restore::UploadRestorer.new(
    paths[:uploads_path],
    logger: logger,
    skip_validation: @options[:skip_upload_validation],
    threads: @options[:jobs]
  )
  upload_restorer.restore

  report_summary(logger)
  0
end

def report_summary(logger)
  if logger.warnings?
    logger.log "\nRestore completed with warnings!"
    logger.log "Review the log file for details."
  else
    logger.log "\nRestore completed successfully!"
  end
end
```

---

---

### Chunk 12: Backup Command - Basic Structure
**~60-80 lines**

```ruby
# lib/disco/commands/backup.rb
module Disco
  module Commands
    class Backup < Samovar::Command
      self.description = "Create a backup"

      options do
        option "--no-uploads", "Exclude uploads from backup"
        option "--no-optimized", "Exclude optimized images"
        option "-o/--output <path>", "Output path for backup file"
      end

      def call
        load_rails
        logger = Disco::Logger.new

        logger.log "Discourse Backup"
        logger.log "================"

        # TODO: Implementation
        logger.log "Creating backup..."
      end
    end
  end
end
```

**Test:** Spec for option parsing.

---

### Chunk 13: Database Dumper
**~80-100 lines**

Dump database using pg_dump:

```ruby
# lib/disco/backup/database_dumper.rb
module Disco
  module Backup
    class DatabaseDumper
      def initialize(logger:)
        @logger = logger
        @env = Database.psql_env
      end

      def dump_to(output_stream)
        Open3.popen3(@env, *pg_dump_command) do |stdin, stdout, stderr, wait_thread|
          stdin.close

          IO.copy_stream(stdout, output_stream)

          exit_status = wait_thread.value
          unless exit_status.success?
            raise "pg_dump failed: #{stderr.read}"
          end
        end
      end

      private

      def pg_dump_command
        [
          "pg_dump",
          "--no-owner",
          "--no-privileges",
          "--compress=4",
          "--quote-all-identifiers",
          "--schema=public",
          "--serializable-deferrable"
        ]
      end
    end
  end
end
```

**Test:** Spec that verifies dump is valid SQL.

---

### Chunk 14: Local Upload Collector
**~60-80 lines**

Collect local uploads for backup:

```ruby
# lib/disco/backup/local_upload_collector.rb
module Disco
  module Backup
    class LocalUploadCollector
      def initialize(logger:)
        @logger = logger
      end

      def each_upload
        return enum_for(:each_upload) unless block_given?

        # Only local uploads (URL starts with / but not //)
        Upload.where("url LIKE '/%' AND url NOT LIKE '//%'").find_each do |upload|
          path = Discourse.store.path_for(upload)
          next unless path && File.exist?(path)
          yield upload, path
        end
      end
    end
  end
end
```

**Test:** Spec with fabricated local uploads.

---

### Chunk 15: S3 Upload Collector with Deduplication
**~100-120 lines**

Collect S3 uploads with hardlink deduplication (from PR #37261):

```ruby
# lib/disco/backup/s3_upload_collector.rb
module Disco
  module Backup
    # Lightweight struct to avoid holding full AR objects in memory
    UploadData = Struct.new(:id, :url, :sha1, keyword_init: true)

    class S3UploadCollector
      def initialize(tmp_dir, logger:)
        @tmp_dir = tmp_dir
        @logger = logger
        @store = FileStore::S3Store.new
        @stats = { downloaded: 0, hardlinked: 0, failed: 0 }
      end

      attr_reader :stats

      def collect_uploads
        uploads_by_sha1 = group_by_content_hash
        @logger.log "Found #{uploads_by_sha1.size} unique files from #{total_count(uploads_by_sha1)} uploads"

        uploads_by_sha1.each_value { |group| process_group(group) }

        @logger.log "Downloads: #{@stats[:downloaded]}, Hardlinked: #{@stats[:hardlinked]}, Failed: #{@stats[:failed]}"
      end

      private

      def group_by_content_hash
        # Use original_sha1 if available, fall back to sha1
        Upload
          .where("url NOT LIKE '/%' OR url LIKE '//%'")
          .pluck(Arel.sql("COALESCE(NULLIF(original_sha1, ''), sha1)"), :id, :url, :sha1)
          .group_by(&:first)
          .transform_values { |rows| rows.map { |_, id, url, sha1| UploadData.new(id:, url:, sha1:) } }
      end

      def process_group(group)
        primary = group.first
        primary_path = download(primary)
        return unless primary_path

        group.drop(1).each { |dup| hardlink_or_download(primary_path, dup) }
      end

      def download(upload_data)
        path = target_path(upload_data)
        FileUtils.mkdir_p(File.dirname(path))
        @store.download_file(upload_data, path)
        @stats[:downloaded] += 1
        path
      rescue => e
        @logger.warn "Failed to download upload #{upload_data.id}: #{e.message}"
        @stats[:failed] += 1
        nil
      end

      def hardlink_or_download(source, upload_data)
        target = target_path(upload_data)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.ln(source, target)
        @stats[:hardlinked] += 1
      rescue
        download(upload_data)
      end

      def target_path(upload_data)
        File.join(@tmp_dir, Discourse.store.upload_path, @store.get_path_for_upload(upload_data))
      end

      def total_count(grouped)
        grouped.values.sum(&:size)
      end
    end
  end
end
```

**Test:** Spec with mocked S3 store, verify hardlinks created.

---

### Chunk 16: Archive Writer (v1 format)
**~100-120 lines**

Create backup archive in v1 format:

```ruby
# lib/disco/backup/archive_writer.rb
module Disco
  module Backup
    class ArchiveWriter
      def initialize(output_path, logger:)
        @output_path = output_path
        @logger = logger
        @tmp_dir = Dir.mktmpdir("discourse-backup")
      end

      def write(include_uploads: true)
        dump_path = dump_database

        if include_uploads
          write_tar_with_uploads(dump_path)
        else
          # Just the SQL dump
          FileUtils.mv(dump_path, @output_path)
        end
      ensure
        FileUtils.rm_rf(@tmp_dir)
      end

      private

      def dump_database
        dump_path = File.join(@tmp_dir, "dump.sql.gz")
        File.open(dump_path, "wb") do |file|
          DatabaseDumper.new(logger: @logger).dump_to(file)
        end
        dump_path
      end

      def write_tar_with_uploads(dump_path)
        tar_path = @output_path.sub(/\.gz$/, "")

        system("tar", "-cf", tar_path, "-C", @tmp_dir, "dump.sql.gz")

        # Add uploads directory
        uploads_dir = File.join(Rails.root, "public", "uploads")
        if File.directory?(uploads_dir)
          system("tar", "-rf", tar_path, "-C", File.dirname(uploads_dir), "uploads")
        end

        system("gzip", tar_path)
      end
    end
  end
end
```

**Test:** Spec that creates and verifies archive structure.

---

### Chunk 17: Backup Command - Full Implementation
**~60-80 lines**

Wire backup together:

```ruby
# lib/disco/commands/backup.rb (updated)
def call
  load_rails
  logger = Disco::Logger.new

  logger.log "Discourse Backup"
  logger.log "================"

  output_path = @options[:output] || default_output_path
  include_uploads = !@options[:no_uploads]

  logger.log "[1/3] Creating database dump..."

  logger.log "[2/3] Packaging #{include_uploads ? 'with' : 'without'} uploads..."
  writer = Backup::ArchiveWriter.new(output_path, logger: logger)
  writer.write(include_uploads: include_uploads)

  logger.log "[3/3] Finalizing..."

  logger.log "\nBackup created: #{output_path}"
  0
end

private

def default_output_path
  timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%SZ")
  title = SiteSetting.title.parameterize.presence || "discourse"
  "#{title}-#{timestamp}.tar.gz"
end
```

---

---

### Chunk 18: Upload Restorer (non-fatal)
**~100-120 lines**

Restore uploads with non-fatal error handling. **Key change: bypass the `migration_successful?` check** that currently aborts restore.

Current problem:
```
restore_uploads → S3Store.copy_from → ToS3Migration.migrate_to_s3
→ migration_successful?(should_raise: true) → posts:missing_uploads → EXCEPTION
```

Our approach: Handle uploads ourselves, bypass the migration validation, report issues without failing.

```ruby
# lib/disco/restore/upload_restorer.rb
module Disco
  module Restore
    class UploadRestorer
      def initialize(uploads_path, logger:, skip_validation: false)
        @uploads_path = uploads_path
        @logger = logger
        @skip_validation = skip_validation
        @stats = { restored: 0, failed: 0, missing_in_db: 0 }
      end

      attr_reader :stats

      def restore
        return unless @uploads_path && File.directory?(@uploads_path)

        if local_storage?
          restore_to_local
        else
          restore_to_s3
        end

        validate_uploads unless @skip_validation
        report_stats
      end

      private

      def local_storage?
        !SiteSetting::Upload.enable_s3_uploads
      end

      def restore_to_local
        target_dir = File.join(Rails.root, "public", "uploads")

        Dir.glob(File.join(@uploads_path, "**", "*")).each do |source|
          next if File.directory?(source)
          restore_local_file(source, target_dir)
        end
      end

      def restore_to_s3
        # Use S3Store but catch failures per-file instead of aborting
        store = FileStore::S3Store.new

        Dir.glob(File.join(@uploads_path, "**", "*")).each do |source|
          next if File.directory?(source)
          upload_to_s3(store, source)
        end
      end

      def restore_local_file(source, target_dir)
        relative = source.sub("#{@uploads_path}/", "")
        target = File.join(target_dir, relative)

        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)
        @stats[:restored] += 1
      rescue => e
        @logger.warn "Failed to restore #{relative}: #{e.message}"
        @stats[:failed] += 1
      end

      def upload_to_s3(store, source)
        # Upload individual file, catch errors
        @stats[:restored] += 1
      rescue => e
        @logger.warn "Failed to upload to S3: #{e.message}"
        @stats[:failed] += 1
      end

      def validate_uploads
        # Light validation: count files vs DB records, but DON'T fail
        db_count = Upload.count
        @stats[:missing_in_db] = [db_count - @stats[:restored], 0].max
      end

      def report_stats
        @logger.log "Uploads restored: #{@stats[:restored]}"

        if @stats[:failed] > 0
          @logger.warn "#{@stats[:failed]} uploads failed to restore"
        end

        if @stats[:missing_in_db] > 0
          @logger.warn "#{@stats[:missing_in_db]} uploads referenced in DB but not in backup"
          @logger.log "Run `rake uploads:missing` after restore to identify issues"
        end
      end
    end
  end
end
```

**Test:** Spec with temp directory structure, verify failures don't abort.

---

### Chunk 19: Parallel S3 Worker
**~80-100 lines**

Parallel upload/download for S3 operations:

```ruby
# lib/disco/s3_worker_pool.rb
module Disco
  class S3WorkerPool
    def initialize(store:, threads: 4, logger:)
      @store = store
      @threads = threads
      @logger = logger
      @queue = Queue.new
      @stats = Concurrent::Hash.new(0)
      @mutex = Mutex.new
    end

    attr_reader :stats

    def enqueue_download(upload_data, target_path)
      @queue << [:download, upload_data, target_path]
    end

    def enqueue_upload(source_path, s3_path)
      @queue << [:upload, source_path, s3_path]
    end

    def run
      workers = @threads.times.map do
        Thread.new { process_queue }
      end

      @queue.close
      workers.each(&:join)
    end

    def close_queue
      @queue.close
    end

    private

    def process_queue
      while (job = @queue.pop)
        case job[0]
        when :download
          download(*job[1..])
        when :upload
          upload(*job[1..])
        end
      end
    end

    def download(upload_data, target_path)
      FileUtils.mkdir_p(File.dirname(target_path))
      @store.download_file(upload_data, target_path)
      increment(:downloaded)
    rescue => e
      @logger.warn "Download failed for #{upload_data.id}: #{e.message}"
      increment(:failed)
    end

    def upload(source_path, s3_path)
      @store.upload_file(source_path, s3_path)
      increment(:uploaded)
    rescue => e
      @logger.warn "Upload failed for #{s3_path}: #{e.message}"
      increment(:failed)
    end

    def increment(key)
      @mutex.synchronize { @stats[key] += 1 }
      log_progress
    end

    def log_progress
      total = @stats[:downloaded] + @stats[:uploaded] + @stats[:failed]
      @logger.log "Processed #{total} files..." if total % 500 == 0
    end
  end
end
```

**Test:** Spec with mocked S3 store, verify parallel execution.

---

### Chunk 20: URL Remapper (standalone)
**~100-120 lines**

Remap URLs in database - works independently of upload restore. Essential for:
- SQL-only backups restored to different domain
- Full backups where uploads are restored separately

```ruby
# lib/disco/restore/url_remapper.rb
module Disco
  module Restore
    class UrlRemapper
      # Can be initialized from backup metadata OR manually provided settings
      def initialize(old_settings, logger:)
        @old = old_settings
        @new = current_settings
        @logger = logger
      end

      def remap
        mappings = build_mappings
        if mappings.empty?
          @logger.log "No URL remapping needed"
          return
        end

        @logger.log "Remapping #{mappings.size} URL patterns..."
        mappings.each do |from, to|
          @logger.log "  #{from} -> #{to}"
          DbHelper.remap(from, to, excluded_tables: ["backup_metadata"])
        end
        @logger.log "URL remapping complete"
      end

      # For SQL-only backups without metadata, allow manual specification
      def self.from_urls(old_base_url:, new_base_url:, logger:, **opts)
        old_settings = {
          base_url: old_base_url,
          cdn_url: opts[:old_cdn_url],
          s3_base_url: opts[:old_s3_base_url],
          s3_cdn_url: opts[:old_s3_cdn_url]
        }
        new(old_settings, logger: logger)
      end

      private

      def build_mappings
        mappings = {}

        # Base URL (most common case)
        if @old[:base_url] && @old[:base_url] != @new[:base_url]
          mappings[@old[:base_url]] = @new[:base_url]
        end

        # CDN URL
        if @old[:cdn_url].present? && @old[:cdn_url] != @new[:cdn_url]
          target = @new[:cdn_url].presence || @new[:base_url]
          mappings[@old[:cdn_url]] = target
        end

        # S3 base URL
        if @old[:s3_base_url].present? && @old[:s3_base_url] != @new[:s3_base_url]
          target = @new[:s3_base_url].presence || @new[:base_url]
          mappings[@old[:s3_base_url]] = target
        end

        # S3 CDN URL
        if @old[:s3_cdn_url].present? && @old[:s3_cdn_url] != @new[:s3_cdn_url]
          target = @new[:s3_cdn_url].presence || @new[:s3_base_url].presence || @new[:base_url]
          mappings[@old[:s3_cdn_url]] = target
        end

        mappings
      end

      def current_settings
        {
          base_url: Discourse.base_url,
          cdn_url: GlobalSetting.cdn_url,
          s3_base_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_base_url : nil,
          s3_cdn_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : nil
        }
      end
    end
  end
end
```

**Test:** Spec with various URL combinations, including SQL-only backup case.

---

### Chunk 20: Missing Upload Downloader
**~80-100 lines**

Try to recover missing uploads:

```ruby
# lib/disco/restore/missing_upload_downloader.rb
module Disco
  module Restore
    class MissingUploadDownloader
      def initialize(logger:)
        @logger = logger
        @stats = { recovered: 0, failed: 0 }
      end

      attr_reader :stats

      def download_missing
        missing = Upload.where("url IS NOT NULL").find_each.select { |u| !file_exists?(u) }
        return if missing.empty?

        @logger.log "Attempting to recover #{missing.count} missing uploads..."

        missing.each do |upload|
          recover(upload)
        end

        @logger.log "Recovered: #{@stats[:recovered]}, Still missing: #{@stats[:failed]}"
      end

      private

      def recover(upload)
        # Try sources in order
        recovered = try_url(upload) ||
                    try_origin(upload) ||
                    try_s3(upload)

        if recovered
          @stats[:recovered] += 1
        else
          @stats[:failed] += 1
        end
      end

      def try_url(upload)
        return false if upload.url.blank?
        download_from(upload.url, upload)
      end

      def try_origin(upload)
        return false if upload.origin.blank?
        download_from(upload.origin, upload)
      end

      def try_s3(upload)
        # If S3 credentials available, try direct S3 download
        false # TODO: implement
      end

      def download_from(url, upload)
        # Use FileHelper to download
        false
      rescue
        false
      end

      def file_exists?(upload)
        path = Discourse.store.path_for(upload)
        path && File.exist?(path)
      end
    end
  end
end
```

**Test:** Spec with mocked HTTP responses.

---

---

### Chunk 21: Missing Upload Downloader
**~80-100 lines**

(Same as before - try to recover missing uploads from url/origin/S3)

---

### Future Chunks (polish and extras)

22. **Version Validation** - Check versions, `--force` flag
23. **Progress Indicators** - Spinners, progress bars
24. **Background Job Integration** - MessageBus logging
25. **S3 Storage for Backups** - Store backups on S3
26. **New Backup Format (v2)** - meta.json, streaming with mini_tarball
27. **Optimized Images** - Backup/restore optimized images separately
28. **Remap Command** - Standalone `disco remap` for SQL-only backups

---

## File Structure

```
lib/
├── disco.rb
└── disco/
    ├── application.rb
    ├── logger.rb
    ├── database.rb
    ├── commands/
    │   ├── backup.rb
    │   └── restore.rb
    ├── backup/
    │   ├── database_dumper.rb
    │   ├── local_upload_collector.rb
    │   ├── s3_upload_collector.rb
    │   └── archive_writer.rb
    └── restore/
        ├── sql_reader.rb
        ├── psql_writer.rb
        ├── error_parser.rb
        ├── error_handler.rb
        ├── database_restorer.rb
        ├── backup_extractor.rb
        ├── upload_restorer.rb
        ├── url_remapper.rb
        └── missing_upload_downloader.rb

script/
└── disco

spec/
└── lib/
    └── disco/
        ├── logger_spec.rb
        ├── database_spec.rb
        ├── commands/
        │   ├── backup_spec.rb
        │   └── restore_spec.rb
        ├── backup/
        │   ├── database_dumper_spec.rb
        │   ├── local_upload_collector_spec.rb
        │   ├── s3_upload_collector_spec.rb
        │   └── archive_writer_spec.rb
        └── restore/
            ├── sql_reader_spec.rb
            ├── psql_writer_spec.rb
            ├── error_parser_spec.rb
            ├── database_restorer_spec.rb
            ├── upload_restorer_spec.rb
            ├── url_remapper_spec.rb
            └── missing_upload_downloader_spec.rb
```

---

## Next Steps

1. **You work on mini_tarball** - Reader implementation
2. **I start Chunk 1** - CLI skeleton with Samovar
3. **Review and iterate** - Small PRs, tests included

Ready to start with Chunk 1?
