# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Named SQL fragments that genuinely differ between the source backends, so
      # the `Source` can author one canonical query and drop a `dialect.<fragment>`
      # at each divergent spot — instead of writing MySQL and regex-substituting
      # for Postgres (which fails on the aggregate-building constructs below) or
      # maintaining a `Database3` / `Database3Postgres` class per backend.
      #
      # The set is deliberately small: it covers every divergence in the real
      # phpBB queries (`epoch_now` for the banlist check; JSON / id-array
      # aggregation for attachments and PM recipients; identifier quoting) and
      # nothing speculative.
      #
      # `id_array_agg` is the load-bearing case: on MySQL it builds a fake-JSON
      # string (`"[1,2,3]"`), on Postgres a real JSON array. The connection
      # normalizes both to parsed Ruby before the row leaves the parent, so a step
      # always receives `item[:recipients] == [1, 2, 3]`.
      #
      # This lives in the phpBB converter for now; promote it to a shared SQL
      # Source toolkit once a second SQL converter needs it.
      class Dialect
        UnknownDialect = Class.new(ArgumentError)

        # @param type [Symbol, String] `:mysql` or `:postgres`.
        # @return [Dialect]
        def self.for(type)
          case type.to_sym
          when :mysql
            MySQL.new
          when :postgres
            Postgres.new
          else
            raise UnknownDialect, "Unknown SQL dialect: #{type.inspect}"
          end
        end

        # Current Unix timestamp, for comparing against phpBB's integer time
        # columns (e.g. `ban_end`).
        def epoch_now
          raise NotImplementedError
        end

        # Aggregate `expr` across a group into a JSON array.
        def json_array_agg(_expr)
          raise NotImplementedError
        end

        # Build a JSON object from `pairs` (a `'key', value, ...` fragment).
        def json_object(_pairs)
          raise NotImplementedError
        end

        # Aggregate the distinct ids in `expr` into something the connection
        # normalizes to a Ruby array of integers.
        def id_array_agg(_expr)
          raise NotImplementedError
        end

        # Quote `name` as an identifier for this backend.
        def quote_identifier(_name)
          raise NotImplementedError
        end

        class MySQL < Dialect
          def epoch_now
            "UNIX_TIMESTAMP()"
          end

          def json_array_agg(expr)
            "JSON_ARRAYAGG(#{expr})"
          end

          def json_object(pairs)
            "JSON_OBJECT(#{pairs})"
          end

          def id_array_agg(expr)
            "CONCAT('[', GROUP_CONCAT(DISTINCT #{expr}), ']')"
          end

          def quote_identifier(name)
            "`#{name.to_s.gsub("`", "``")}`"
          end
        end

        class Postgres < Dialect
          def epoch_now
            "EXTRACT(EPOCH FROM NOW())::bigint"
          end

          def json_array_agg(expr)
            "json_agg(#{expr})"
          end

          def json_object(pairs)
            "jsonb_build_object(#{pairs})"
          end

          def id_array_agg(expr)
            "json_agg(DISTINCT #{expr})"
          end

          def quote_identifier(name)
            %("#{name.to_s.gsub('"', '""')}")
          end
        end
      end
    end
  end
end
