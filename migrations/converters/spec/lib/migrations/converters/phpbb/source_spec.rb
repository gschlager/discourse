# frozen_string_literal: true

# Retrieval lint: runs the phpBB Source's queries against a real phpBB schema
# across {3.0, 3.1, 3.2, 3.3} x {mysql, postgres}, with no data — so it catches
# dialect/version mismatches (the class of bug the legacy converter had: Postgres
# 3.1+ dying on UNIX_TIMESTAMP, or an introspection probe leaking across
# databases). The queries only have to execute against the real DDL.
#
# It connects to databases named `phpbb_30` … `phpbb_33` as `phpbb`/`phpbb`
# (override via PHPBB_* env). Each (backend, version) cell skips itself when its
# database isn't reachable, so the normal suite stays database-free; a dedicated
# CI job (MariaDB + Postgres services) provisions the schemas and runs the grid.
RSpec.describe Migrations::Converters::Phpbb::Source do
  # database => whether `user_website`/`user_from` were relocated into
  # profile_fields_data (3.1 onwards).
  versions = { "phpbb_30" => false, "phpbb_31" => true, "phpbb_32" => true, "phpbb_33" => true }

  def settings_for(type, database)
    {
      type:,
      table_prefix: "phpbb_",
      mysql: {
        host: ENV["PHPBB_MYSQL_HOST"] || "127.0.0.1",
        port: (ENV["PHPBB_MYSQL_PORT"] || 3306).to_i,
        username: ENV["PHPBB_MYSQL_USER"] || "phpbb",
        password: ENV["PHPBB_MYSQL_PASSWORD"] || "phpbb",
        database:,
      },
      postgres: {
        host: ENV["PHPBB_PG_HOST"] || "127.0.0.1",
        port: (ENV["PHPBB_PG_PORT"] || 5432).to_i,
        user: ENV["PHPBB_PG_USER"] || "phpbb",
        password: ENV["PHPBB_PG_PASSWORD"] || "phpbb",
        dbname: database,
      },
    }
  end

  def source_for(type, database)
    described_class.create(settings_for(type, database))
  rescue StandardError
    nil
  end

  %i[mysql postgres].each do |backend|
    describe "against a real phpBB #{backend} database" do
      versions.each do |database, relocated|
        context "on #{database}" do
          let(:source) { source_for(backend, database) }

          before { skip "no reachable #{backend} #{database}" if source.nil? }
          after { source&.close }

          it "resolves the version-variable columns and runs fetch_users" do
            caps = source.capabilities

            if relocated
              expect(caps.user_website_expr).to eq("f.pf_phpbb_website")
              expect(caps.user_location_expr).to eq("f.pf_phpbb_location")
              expect(caps.profile_fields_join).to include("profile_fields_data")
            else
              expect(caps.user_website_expr).to eq("u.user_website")
              expect(caps.user_location_expr).to eq("u.user_from")
              expect(caps.profile_fields_join).to eq("")
            end

            # The queries execute against the real DDL (no rows seeded).
            expect(source.count_users).to eq(0)
            expect(source.fetch_users.to_a).to eq([])
            expect(source.config).to eq({})
          end
        end
      end
    end
  end
end
