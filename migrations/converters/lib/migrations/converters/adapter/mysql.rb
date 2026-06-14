# frozen_string_literal: true

require "mysql2"

module Migrations
  module Converters
    module Adapter
      # mysql2-backed source connection, mirroring {Adapter::Postgres}: results
      # stream lazily (so unbounded `SELECT`s don't buffer in memory) and come back
      # as symbol-keyed row hashes with native Ruby types. Used by SQL converters
      # whose source is MySQL or MariaDB (e.g. phpBB).
      class Mysql
        def initialize(settings)
          @settings =
            settings.merge(symbolize_keys: true, cast_booleans: false, database_timezone: :utc)
          @client = Mysql2::Client.new(@settings)
        end

        # @return [Enumerator] a lazy stream of symbol-keyed row hashes.
        def query(sql)
          result = @client.query(sql, stream: true, cache_rows: false, as: :hash)

          Enumerator.new { |y| result.each { |row| y.yield(row) } }
        end

        def query_first_row(sql)
          @client.query(sql, as: :hash, cache_rows: true).first
        end

        def query_value(sql, column = nil)
          if (row = query_first_row(sql))
            column ? row[column.to_sym] : row.values.first
          end
        end

        def count(sql)
          query_value(sql).to_i
        end

        def close
          @client&.close
          @client = nil
        end

        def reset
          close
          @client = Mysql2::Client.new(@settings)
        end
      end
    end
  end
end
