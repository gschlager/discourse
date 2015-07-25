require_relative 'database_base'

module ImportScripts::PhpBB3
  class DatabaseVersionDetector < DatabaseBase
    def get_phpbb_version
      @database
        .from(table(:config))
        .where(:config_name => 'version')
        .get(:config_value)
    end
  end
end

