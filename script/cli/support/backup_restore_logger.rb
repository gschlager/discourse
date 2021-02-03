# frozen_string_literal: true

require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestore::Logger
    include HasSpinner

    def step(name)
      spin(name) do
        super
      end
    end
  end
end
