# frozen_string_literal: true

module BackupRestoreNew
  module Backup
    class MetadataWriter
      def write(output_stream)
        output_stream.write({
          version: BackupRestore.current_version
        }.to_json)
      end
    end
  end
end
