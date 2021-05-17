# frozen_string_literal: true

module BackupRestoreNew
  DatabaseConfiguration = Struct.new(:host, :port, :username, :password, :database)

  class Database
    MAIN_SCHEMA = "public"

    def self.database_configuration
      config = ActiveRecord::Base.connection_pool.db_config.configuration_hash
      config = config.with_indifferent_access

      # credentials for PostgreSQL in CI environment
      if Rails.env.test?
        username = ENV["PGUSER"]
        password = ENV["PGPASSWORD"]
      end

      DatabaseConfiguration.new(
        config["backup_host"] || config["host"],
        config["backup_port"] || config["port"],
        config["username"] || username || ENV["USER"] || "postgres",
        config["password"] || password,
        config["database"]
      )
    end
  end
end
