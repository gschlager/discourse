# frozen_string_literal: true

require 'rails_helper'

describe BackupRestoreNew::Backuper do
  fab!(:admin) { Fabricate(:admin) }
  let!(:factory) do
    logger = Class.new(BackupRestoreNew::Logger::Base) do
      def log(message, level: nil); end
      def log_progress(current_progress); end
    end.new

    BackupRestoreNew::Factory.new(logger)
  end

  subject { described_class.new(admin.id, factory) }

  it "successfully creates a backup" do
    subject
  end
end
