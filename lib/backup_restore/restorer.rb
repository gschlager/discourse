# frozen_string_literal: true

module BackupRestore
  class Restorer
    delegate :log, to: :@logger, private: true
    delegate :step, to: :@logger, private: true

    # @param factory [BackupRestore::Factory]
    def initialize(factory:)
      @logger = factory.logger
    end

    def run
      step("Preparing restore") do
        sleep(5)
      end
    end
  end
end
