# frozen_string_literal: true

module BackupRestore
  class NoopLogger
    def log(message, ex = nil); end
  end
end
