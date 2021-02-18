# frozen_string_literal: true

require 'mini_tarball'

module BackupRestore
  DatabaseBackupError = Class.new(RuntimeError)

  class SimpleBackuper
    def run
      timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      filename = "backup-#{timestamp}.tar"
      tar_path = File.join("/home/gerhard/Documents/test", filename)

      MiniTarball::Writer.create(tar_path) do |writer|
        writer.add_file(name: "dump.sql.gz") do |output_stream|
          dump_public_schema(output_stream)
        end
      end
    end

    protected

    def dump_public_schema(dump_output_stream)
      Open3.popen3(pg_dump_command) do |_, stdout, stderr, thread|
        threads = [thread]

        threads << Thread.new do
          IO.copy_stream(stdout, dump_output_stream)
        end

        threads << Thread.new do
          while line = stderr.readline
            puts line
          end
        rescue EOFError
          # finished reading...
        end

        threads.each(&:join)
      end

      raise DatabaseBackupError.new("pg_dump failed") if Process.last_status&.exitstatus != 0
    end

    def pg_dump_command
      db_conf = BackupRestore.database_configuration

      password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
      host_argument     = "--host=#{db_conf.host}"         if db_conf.host.present?
      port_argument     = "--port=#{db_conf.port}"         if db_conf.port.present?
      username_argument = "--username=#{db_conf.username}" if db_conf.username.present?

      [ password_argument,            # pass the password to pg_dump (if any)
        "pg_dump",                    # the pg_dump command
        "--schema=public",            # only public schema
        "-T public.pg_*",             # exclude tables and views whose name starts with "pg_"
        "--no-owner",                 # do not output commands to set ownership of objects
        "--no-privileges",            # prevent dumping of access privileges
        "--compress=4",               # Compression level of 4
        host_argument,                # the hostname to connect to (if any)
        port_argument,                # the port to connect to (if any)
        username_argument,            # the username to connect as (if any)
        db_conf.database              # the name of the database to dump
      ].compact.join(" ")
    end
  end
end
