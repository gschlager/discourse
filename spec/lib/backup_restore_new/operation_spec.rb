# frozen_string_literal: true

require 'rails_helper'

describe BackupRestoreNew::Operation do
  before do
    Discourse.redis.del(described_class::RUNNING_KEY)
    Discourse.redis.del(described_class::ABORT_KEY)
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
    threads = described_class.start
    expect(threads.size).to eq(2)
    threads.each { |t| expect(t.status).to be_truthy }

    described_class.finish
    threads.each { |t| expect(t.status).to be_falsey }
  end

  it "exits the process when abort signal is set" do
    threads = described_class.start

    expect do
      described_class.abort!
      threads.each(&:join)
    end.to raise_error(SystemExit)

    described_class.finish
    threads.each { |t| expect(t.status).to be_falsey }
  end

  it "clears an existing abort signal before it starts" do
    described_class.abort!
    expect(described_class.should_abort?).to eq(true)

    described_class.start
    expect(described_class.should_abort?).to eq(false)
    described_class.finish
  end
end
