# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Targeted introspection of the handful of columns that move across phpBB
      # versions, so the `Source` can resolve them through named seams instead of a
      # version-keyed class hierarchy. The version string is logged, never branched
      # on for schema shape.
      #
      # The one real delta across 3.0 -> 3.3 is `user_website` / `user_from`
      # relocating into `profile_fields_data` in 3.1; probe for it rather than
      # trusting the reported version.
      #
      # TODO (fill-in): probe via the SQL toolkit's introspector and return the
      # resolved expressions / joins.
      class Capabilities
        # @param connection [Object] the source connection.
        # @param prefix [String] the phpBB table prefix.
        # @return [Capabilities]
        def self.detect(_connection, _prefix)
          raise NotImplementedError
        end
      end
    end
  end
end
