module ImportScripts::PhpBB3
  class DatabaseBase
    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def initialize(database, database_settings)
      @database = database

      @batch_size = database_settings.batch_size
      @table_prefix = database_settings.table_prefix
      @db_type = database_settings.type.downcase
    end

    protected

    def table(table_name, table_alias = nil)
      if table_alias.nil?
        "#{@table_prefix}_#{table_name}".to_sym
      else
        "#{@table_prefix}_#{table_name}___#{table_alias}".to_sym
      end
    end

    def position(column, substring)
      case @db_type
        when 'mysql', 'mariadb', 'oracle'
          Sequel.function(:instr, column, substring)
        when 'mssql'
          Sequel.function(:charindex, substring, column)
        when 'postgresql'
          Sequel.function(:position, Sequel.lit('? in ?', substring, column))
        else
          raise "The database type '#{@db_type}' is not supported."
      end
    end

    def substring(column, start_position)
      case @db_type
        when 'mysql', 'mariadb', 'postgresql'
          Sequel.function(:substring, Sequel.lit('? from ?', column, start_position))
        when 'mssql'
          Sequel.function(:substring, column, start_position, Sequel.function(:len, column))
        when 'oracle'
          Sequel.function(:substr, column, start_position)
        else
          raise "The database type '#{@db_type}' is not supported."
      end
    end

    def to_char(column)
      case @db_type
        when 'oracle'
          Sequel.function(:to_char, column)
        else
          column
      end
    end
  end
end
