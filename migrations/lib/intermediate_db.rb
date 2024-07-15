# frozen_string_literal: true

require "singleton"

module Migrations
  module IntermediateDb
    def self.setup(db_connection)
      @db = db_connection
    end

    def self.insert(sql, *parameters)
      @db.insert(sql, *parameters)
    end

    def self.close
      @db.close if @db
    end
  end
end
