# frozen_string_literal: true

module BackupRestore

  VERSION_PREFIX = "v"
  DUMP_FILE = "dump.sql.gz"
  UPLOADS_FILE = "uploads.tar.gz"
  OPTIMIZED_IMAGES_FILE = "optimized-images.tar.gz"
  METADATA_FILE = "meta.json"
  LOGS_CHANNEL = "/admin/backups/logs"

  def self.backup!(user_id, opts = {})
    if opts[:fork] == false
      BackupRestore::Backuper.new(
        user_id: user_id,
        filename: opts[:filename],
        factory: BackupRestore::Factory.new(
          user_id: user_id,
          client_id: opts[:client_id]
        ),
        with_uploads: opts[:with_uploads]
      ).run
    else
      spawn_process!(:backup, user_id, opts)
    end
  end

  def self.restore!(user_id, opts = {})
    spawn_process!(:restore, user_id, opts)
  end

  def self.rollback!
    raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    if can_rollback?
      move_tables_between_schemas("backup", "public")
    end
  end

  def self.cancel!
    set_shutdown_signal!
    true
  end

  def self.can_rollback?
    backup_tables_count > 0
  end

  def self.operations_status
    {
      is_operation_running: is_operation_running?,
      can_rollback: can_rollback?,
      allow_restore: Rails.env.development? || SiteSetting.allow_restore
    }
  end

  def self.logs
    id = start_logs_message_id
    MessageBus.backlog(LOGS_CHANNEL, id).map { |m| m.data }
  end

  def self.current_version
    ActiveRecord::Migrator.current_version
  end

  def self.move_tables_between_schemas(source, destination)
    owner = database_configuration.username

    ActiveRecord::Base.transaction do
      DB.exec(move_tables_between_schemas_sql(source, destination, owner))
    end
  end

  def self.move_tables_between_schemas_sql(source, destination, owner)
    <<~SQL
      DO $$DECLARE row record;
      BEGIN
        -- create <destination> schema if it does not exists already
        -- NOTE: DROP & CREATE SCHEMA is easier, but we don't want to drop the public schema
        -- otherwise extensions (like hstore & pg_trgm) won't work anymore...
        CREATE SCHEMA IF NOT EXISTS #{destination};
        -- move all <source> tables to <destination> schema
        FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = '#{source}'  AND tableowner = '#{owner}'
        LOOP
          EXECUTE 'DROP TABLE IF EXISTS #{destination}.' || quote_ident(row.tablename) || ' CASCADE;';
          EXECUTE 'ALTER TABLE #{source}.' || quote_ident(row.tablename) || ' SET SCHEMA #{destination};';
        END LOOP;
        -- move all <source> views to <destination> schema
        FOR row IN SELECT viewname FROM pg_views WHERE schemaname = '#{source}' AND viewowner = '#{owner}'
        LOOP
          EXECUTE 'DROP VIEW IF EXISTS #{destination}.' || quote_ident(row.viewname) || ' CASCADE;';
          EXECUTE 'ALTER VIEW #{source}.' || quote_ident(row.viewname) || ' SET SCHEMA #{destination};';
        END LOOP;
      END$$;
    SQL
  end

  private

  def self.spawn_process!(type, user_id, opts)
    script = File.join(Rails.root, "script", "spawn_backup_restore.rb")
    command = ["bundle", "exec", "ruby", script, type, user_id, opts.to_json].map(&:to_s)

    pid = spawn({ "RAILS_DB" => RailsMultisite::ConnectionManagement.current_db }, *command)
    Process.detach(pid)
  end

  def self.backup_tables_count
    DB.query_single(<<~SQL).first.to_i
      SELECT COUNT(*) AS count
      FROM information_schema.tables
      WHERE table_schema = 'backup'
    SQL
  end
end
