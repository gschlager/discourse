# frozen_string_literal: true

module BackupRestoreNew
  module Backup
    DatabaseBackupError = Class.new(RuntimeError)

    class DatabaseDumper
      attr_reader :log_lines

      def initialize(schema: BackupRestoreNew::MAIN_SCHEMA, verbose: false)
        @schema = schema
        @verbose = verbose
        @log_lines = []
      end

      def dump_schema(dump_output_stream)
        Open3.popen3(pg_dump_command) do |_, stdout, stderr, thread|
          threads = [thread]

          threads << Thread.new do
            IO.copy_stream(stdout, dump_output_stream)
          end

          threads << Thread.new do
            while line = stderr.readline
              line.chomp!
              @log_lines << line
            end
          rescue EOFError
            # finished reading...
          end

          threads.each(&:join)
        end

        last_line = @log_lines.last
        if Process.last_status&.exitstatus != 0 || last_line&.delete_prefix!("pg_dump: error: ")
          raise DatabaseBackupError.new("pg_dump failed: #{last_line}")
        end
      end

      protected

      def pg_dump_command
        db_conf = BackupRestore.database_configuration

        password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
        host_argument     = "--host=#{db_conf.host}"           if db_conf.host.present?
        port_argument     = "--port=#{db_conf.port}"           if db_conf.port.present?
        username_argument = "--username=#{db_conf.username}"   if db_conf.username.present?
        verbose           = "--verbose"                        if @verbose

        [ password_argument,            # pass the password to pg_dump (if any)
          "pg_dump",                    # the pg_dump command
          "--schema=#{@schema}",        # only public schema
          "-T #{@schema}.pg_*",         # exclude tables and views whose name starts with "pg_"
          "--no-owner",                 # do not output commands to set ownership of objects
          "--no-privileges",            # prevent dumping of access privileges
          "--compress=4",               # Compression level of 4
          verbose,                      # specifies verbose mode (if enabled)
          host_argument,                # the hostname to connect to (if any)
          port_argument,                # the port to connect to (if any)
          username_argument,            # the username to connect as (if any)
          db_conf.database              # the name of the database to dump
        ].compact.join(" ")
      end
    end
  end
end
