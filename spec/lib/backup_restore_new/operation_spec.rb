# frozen_string_literal: true

require 'rails_helper'

describe BackupRestoreNew::Operation do
  before do
    Discourse.redis.del(described_class::KEY)
  end

  it "successfully marks operation as running and finished" do
    expect(described_class.running?).to eq(false)

    described_class.start
    expect(described_class.running?).to eq(true)

    expect { described_class.start }.to raise_error(BackupRestoreNew::OperationRunningError)

    described_class.finish
    expect(described_class.running?).to eq(false)
  end

  it "doesn't leave 🧟 threads running" do
    thread = described_class.start
    expect(thread.status).to be_truthy

    described_class.finish
    expect(thread.status).to be_falsey
  end
end
