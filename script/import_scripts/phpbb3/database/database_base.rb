module ImportScripts::PhpBB3
  class DatabaseBase
    # @param database_client [Mysql2::Client]
    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def initialize(database_client, database_settings)
      @database_client = database_client

      @batch_size = database_settings.batch_size
      @table_prefix = database_settings.table_prefix
      @type = database_settings.type.downcase
    end

    protected

    # Executes a database query.
    def query(sql)
      @database_client.query(sql, cache_rows: false, symbolize_keys: true)
    end

    # Executes a database query and returns the value of the 'count' column.
    def count(sql)
      query(sql).first[:count]
    end

    def unix_timestamp
      Time.now.to_i
    end

    def cast_integer(sql)
      case @type
        when 'mysql', 'mariadb'
          "CAST(#{sql} AS SIGNED INTEGER)"
        when 'postgresql'
          "CAST(#{sql} AS INTEGER)"
        else
          raise "The database type '#{type}' is not supported."
      end
    end

    def position(column, substring)
      case @type
        when 'mysql', 'mariadb', 'oracle', 'sqlite3'
          "INSTR(#{column}, #{substring})"
        when 'mssql'
          "CHARINDEX(#{substring}, #{column})"
        when 'postgresql', 'firebird'
          "POSITION(#{substring} IN #{column})"
        else
          raise "The database type '#{type}' is not supported."
      end
    end

    def substring(column, start_position)
      case @type
        when 'mysql', 'mariadb', 'postgresql', 'firebird'
          "SUBSTRING(#{column} FROM #{start_position})"
        when 'mssql'
          "SUBSTRING(#{column}, #{start_position}, LEN(#{column}))"
        when 'oracle', 'sqlite3'
          "SUBSTR(#{column}, #{start_position})"
        else
          raise "The database type '#{type}' is not supported."
      end
    end
  end
end
