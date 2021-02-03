# frozen_string_literal: true

module BackupRestore
  class Logger
    def initialize
      @steps = []
    end

    def step(name)
      @steps << { name: name, details: [] }
      yield
    end

    def log(message)
      raise NotImplementedError
    end
  end
end
