# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # The phpBB source. A SQL-family Source that exposes each entity as a count
      # and a lazy stream of plain row-hashes — the stable contract every step
      # reads. The retrieval mechanism (mysql2 / pg connection, the dialect, and
      # capability probes for version drift) lives entirely here, in the parent
      # process; workers never hold a handle to it.
      #
      # Version is not a class axis: one `Source` serves 3.0–3.3 across both
      # backends. The backend picks the connection adapter and the `Dialect`; the
      # handful of columns that move between versions are probed once into
      # `Capabilities` and resolved through named seams. This replaces the legacy
      # `Database3` / `Database3_1` / `Database3Postgres` chain (which couldn't
      # express version × dialect and silently sent Postgres 3.1+ to the
      # MySQL-flavoured class).
      class Source
        # Entities still to port from the legacy converter. Each gets a stubbed
        # `count_<entity>` / `fetch_<entity>` until implemented.
        PENDING_ENTITIES = %i[
          anonymous_users
          groups
          group_members
          categories
          topics
          posts
          messages
          polls
          poll_options
          poll_votes
        ].freeze

        # @param settings [Hash] the `source_db` settings block (`type`,
        #   `table_prefix`, and the per-backend connection hash).
        # @return [Source]
        def self.create(settings)
          type = settings.fetch(:type).to_sym
          prefix = settings[:table_prefix] || "phpbb_"

          connection =
            case type
            when :mysql
              Adapter::Mysql.new(settings.fetch(:mysql))
            when :postgres
              Adapter::Postgres.new(settings.fetch(:postgres))
            else
              raise ArgumentError, "Unknown source_db type: #{type.inspect}"
            end

          new(connection, prefix, Dialect.for(type))
        end

        attr_reader :capabilities

        def initialize(connection, table_prefix, dialect)
          @connection = connection
          @prefix = table_prefix
          @dialect = dialect
          @capabilities = Capabilities.detect(connection, table_prefix, dialect)
        end

        def count_users
          @connection.count(<<~SQL)
            SELECT COUNT(*) AS count
            FROM #{@prefix}users
            WHERE user_type <> 2
          SQL
        end

        def fetch_users
          @connection.query(<<~SQL)
            SELECT u.user_id, u.user_email, u.username, u.user_password, u.user_regdate,
                   u.user_lastvisit, u.user_ip, u.user_type, u.user_inactive_reason,
                   g.group_name, b.ban_start, b.ban_end, b.ban_reason, u.user_posts,
                   #{@capabilities.user_website_expr}  AS user_website,
                   #{@capabilities.user_location_expr} AS user_from,
                   u.user_birthday, u.user_avatar_type, u.user_avatar
            FROM #{@prefix}users u
              LEFT JOIN #{@prefix}groups g ON g.group_id = u.group_id
              #{@capabilities.profile_fields_join}
              LEFT JOIN #{@prefix}banlist b ON (
                u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
                (b.ban_end = 0 OR b.ban_end >= #{@dialect.epoch_now})
              )
            WHERE u.user_type <> 2
            ORDER BY u.user_id
          SQL
        end

        # Static phpBB config read once at setup and passed to processors as
        # `phpbb_config` (version + the upload/avatar/smilies paths), as a
        # `{ config_name => config_value }` hash.
        def config
          {}.tap do |config|
            @connection
              .query(<<~SQL)
                SELECT config_name, config_value
                FROM #{@prefix}config
                WHERE config_name IN (
                  'version', 'avatar_path', 'avatar_gallery_path', 'avatar_salt',
                  'smilies_path', 'upload_path'
                )
              SQL
              .each { |row| config[row[:config_name].to_sym] = row[:config_value] }
          end
        end

        def close
          @connection&.close
        end

        PENDING_ENTITIES.each do |entity|
          define_method(:"count_#{entity}") { raise NotImplementedError }
          define_method(:"fetch_#{entity}") { raise NotImplementedError }
        end
      end
    end
  end
end
