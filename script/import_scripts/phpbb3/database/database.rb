require 'sequel'
require_relative 'database_version_detector'

module ImportScripts::PhpBB3
  class Database
    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def self.create(database_settings)
      Database.new(database_settings).create_database
    end

    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def initialize(database_settings)
      @database_settings = database_settings

      change_environment
      @database = create_database_client
      change_database_client_settings
    end

    # @return [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    def create_database
      version = get_phpbb_version

      if version.start_with?('3.0')
        require_relative 'database_3_0'
        Database_3_0.new(@database, @database_settings)
      elsif version.start_with?('3.1')
        require_relative 'database_3_1'
        Database_3_1.new(@database, @database_settings)
      else
        raise UnsupportedVersionError, "Unsupported version (#{version}) of phpBB detected.\n" \
          << 'Currently only 3.0.x and 3.1.x are supported by this importer.'
      end
    end

    protected

    def create_database_client
      Sequel.connect(:adapter => database_adapter,
                     :host => @database_settings.host,
                     :database => @database_settings.database_name,
                     :user => @database_settings.username,
                     :password => @database_settings.password)
    end

    def change_environment
      case @database_settings.type.downcase
        when 'oracle'
          ENV['NLS_LANG'] = @database_settings.nls_lang
      end
    end

    def change_database_client_settings
      case @database_settings.type.downcase
        when 'mysql', 'mariadb'
          @database.convert_tinyint_to_bool = false
      end
    end

    def database_adapter
      case @database_settings.type.downcase
        when 'mysql', 'mariadb'
          'mysql2'
        when 'mssql'
          'tinytds'
        when 'oracle'
          'oracle'
        when 'postgresql'
          'postgres'
        when 'sqlite3'
          'sqlite'
        else
          raise "The database type '#{@database_settings.type}' is not supported."
      end
    end

    def get_phpbb_version
      DatabaseVersionDetector
        .new(@database, @database_settings)
        .get_phpbb_version
    end
  end

  class UnsupportedVersionError < RuntimeError;
  end
end
