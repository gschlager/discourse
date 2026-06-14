# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Targeted introspection of the handful of columns that move across phpBB
      # versions, so the `Source` can resolve them through named seams instead of a
      # version-keyed class hierarchy.
      #
      # The one schema-shape delta across 3.0 -> 3.3 that the converter cares about
      # is `user_website` / `user_from` relocating from `users` into
      # `profile_fields_data` in 3.1 (`Database3_1` overrides only `fetch_users`,
      # and `Database3_3` adds nothing). We probe for the `users.user_website`
      # column rather than trusting the reported version — robust to in-place
      # upgrades and lightly-customised schemas.
      class Capabilities
        # @param connection [#query_value] the source connection.
        # @param prefix [String] the phpBB table prefix.
        # @param dialect [Dialect] the backend dialect (scopes the probe to the
        #   current database).
        # @return [Capabilities]
        def self.detect(connection, prefix, dialect)
          relocated = !column_exists?(connection, dialect, "#{prefix}users", "user_website")

          new(
            user_website_expr: relocated ? "f.pf_phpbb_website" : "u.user_website",
            user_location_expr: relocated ? "f.pf_phpbb_location" : "u.user_from",
            profile_fields_join:
              (
                if relocated
                  "LEFT JOIN #{prefix}profile_fields_data f ON u.user_id = f.user_id"
                else
                  ""
                end
              ),
          )
        end

        # `information_schema.columns` is portable across MySQL and PostgreSQL, but
        # MySQL's is server-wide, so it must be scoped to the connection's schema
        # (`dialect.current_schema`) or the probe leaks across databases.
        def self.column_exists?(connection, dialect, table, column)
          !connection.query_value(<<~SQL).nil?
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = #{dialect.current_schema}
              AND table_name = '#{table}'
              AND column_name = '#{column}'
            LIMIT 1
          SQL
        end
        private_class_method :column_exists?

        attr_reader :user_website_expr, :user_location_expr, :profile_fields_join

        def initialize(user_website_expr:, user_location_expr:, profile_fields_join:)
          @user_website_expr = user_website_expr
          @user_location_expr = user_location_expr
          @profile_fields_join = profile_fields_join
        end
      end
    end
  end
end
