# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        def initialize(settings)
          super
          @source_db = Adapter::Postgres.new(settings[:source_db])
        end

        def step_args(step_class)
          { source_db: @source_db, group_names:, here_mention: }
        end

        private

        # Lowercased source group names, so the Posts step can classify `@group`
        # mentions. Loaded once and shared with every step's processor (steps that
        # don't declare an accessor simply ignore it).
        def group_names
          @group_names ||=
            @source_db.query("SELECT LOWER(name) AS name FROM groups").map { |row| row[:name] }
        end

        # The source's `here_mention` setting value (the configurable name that
        # triggers an `@here` mention); falls back to the Discourse default when the
        # source uses it (defaults aren't stored in `site_settings`).
        def here_mention
          @here_mention ||=
            @source_db.query_value("SELECT value FROM site_settings WHERE name = 'here_mention'") ||
              "here"
        end
      end
    end
  end
end
