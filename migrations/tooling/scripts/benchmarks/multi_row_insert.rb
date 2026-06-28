#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares different ways of encoding bulk INSERTs into the IntermediateDB
# (Extralite/SQLite). All variants use the exact same connection pragmas and
# the same transaction batching as `Migrations::Database::Connection`, so the
# only thing that varies is *how* the rows are handed to SQLite:
#
#   * per_row          - prepared statement executed once per row (status quo)
#   * batch_execute    - Extralite's native `batch_execute`, which re-binds the
#                        prepared statement N times in C instead of in Ruby
#   * multi_row(M)     - INSERT ... VALUES (..), (..), .. with M rows per
#                        statement, so SQLite steps one statement per M rows
#   * multi_row_batch  - multi-row VALUES combined with `batch_execute`
#
# Run with a smaller dataset while iterating:
#
#   ROW_COUNT=1000000 ruby multi_row_insert.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "extralite-bundle", require: "extralite"
end

require "etc"
require "tempfile"

ROW_COUNT = Integer(ENV["ROW_COUNT"] || 5_000_000)
TRANSACTION_SIZE = Integer(ENV["TRANSACTION_SIZE"] || 1000)

COLUMN_COUNT = 4
USER = [1, "John", "john@example.com", "2023-12-29T11:10:04Z"].freeze

CREATE_TABLE_SQL = <<~SQL
  CREATE TABLE users (
    id          INTEGER,
    name        TEXT,
    email       TEXT,
    created_at  DATETIME
  )
SQL
SINGLE_ROW_VALUES = "(?, ?, ?, ?)"
INSERT_SQL = "INSERT INTO users VALUES #{SINGLE_ROW_VALUES}"

# SQLite allows at most SQLITE_MAX_VARIABLE_NUMBER (32766 here) bind parameters
# per statement, which caps how many rows a single multi-row INSERT can carry.
MAX_ROWS_PER_STATEMENT = 32_766 / COLUMN_COUNT

def multi_row_sql(row_count)
  "INSERT INTO users VALUES #{Array.new(row_count, SINGLE_ROW_VALUES).join(", ")}"
end

def with_thousands(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def open_db(path)
  db = Extralite::Database.new(path)
  db.pragma(
    busy_timeout: 60_000,
    journal_mode: "wal",
    synchronous: "off",
    temp_store: "memory",
    locking_mode: "normal",
    cache_size: -10_000, # 10_000 pages
  )
  db
end

def with_db_path
  tempfile = Tempfile.new
  db = open_db(tempfile.path)
  db.execute(CREATE_TABLE_SQL)
  db.close

  yield tempfile.path

  db = open_db(tempfile.path)
  actual = db.query_single_splat("SELECT COUNT(*) FROM users")
  warn "  ⚠️  expected #{ROW_COUNT} rows, got #{actual}" if actual != ROW_COUNT
  db.close
ensure
  tempfile.close
  tempfile.unlink
end

# Wraps writes in transactions of TRANSACTION_SIZE rows, mirroring
# `Migrations::Database::Connection`. Commits are driven by row count so that
# every variant uses the same transaction boundaries regardless of how many
# rows a single statement inserts.
class TransactionBatcher
  def initialize(db)
    @db = db
    @rows_in_transaction = 0
  end

  def add(row_count)
    @db.execute("BEGIN DEFERRED TRANSACTION") if @rows_in_transaction == 0
    yield
    @rows_in_transaction += row_count
    if @rows_in_transaction >= TRANSACTION_SIZE
      @db.execute("COMMIT")
      @rows_in_transaction = 0
    end
  end

  def finish
    if @rows_in_transaction > 0
      @db.execute("COMMIT")
      @rows_in_transaction = 0
    end
  end
end

# Status quo: one prepared statement, executed once per row from Ruby.
def write_per_row(path)
  db = open_db(path)
  stmt = db.prepare(INSERT_SQL)
  batcher = TransactionBatcher.new(db)

  ROW_COUNT.times { batcher.add(1) { stmt.execute(USER) } }

  batcher.finish
  stmt.close
  db.close
end

# Same single-row statement, but Extralite re-binds and steps it N times in C
# via `batch_execute`, avoiding the per-row Ruby method call.
def write_batch_execute(path)
  db = open_db(path)
  batcher = TransactionBatcher.new(db)
  chunk = Array.new(TRANSACTION_SIZE, USER)

  remaining = ROW_COUNT
  while remaining > 0
    size = [TRANSACTION_SIZE, remaining].min
    rows = size == TRANSACTION_SIZE ? chunk : Array.new(size, USER)
    batcher.add(size) { db.batch_execute(INSERT_SQL, rows) }
    remaining -= size
  end

  batcher.finish
  db.close
end

# INSERT ... VALUES (..), (..), .. with `rows_per_statement` tuples per call, so
# SQLite prepares/steps a single statement for many rows.
def write_multi_row(path, rows_per_statement)
  db = open_db(path)
  batcher = TransactionBatcher.new(db)

  full_stmt = db.prepare(multi_row_sql(rows_per_statement))
  full_params = (USER * rows_per_statement).freeze

  remaining = ROW_COUNT
  while remaining >= rows_per_statement
    batcher.add(rows_per_statement) { full_stmt.execute(full_params) }
    remaining -= rows_per_statement
  end

  if remaining > 0
    rem_stmt = db.prepare(multi_row_sql(remaining))
    batcher.add(remaining) { rem_stmt.execute(USER * remaining) }
    rem_stmt.close
  end

  batcher.finish
  full_stmt.close
  db.close
end

# Best of both: a multi-row VALUES statement re-bound several times per
# transaction via `batch_execute`.
def write_multi_row_batch(path, rows_per_statement)
  db = open_db(path)
  batcher = TransactionBatcher.new(db)

  full_sql = multi_row_sql(rows_per_statement)
  full_params = (USER * rows_per_statement).freeze

  statements_per_transaction = [TRANSACTION_SIZE / rows_per_statement, 1].max
  chunk = Array.new(statements_per_transaction, full_params)

  remaining = ROW_COUNT
  while remaining >= rows_per_statement
    count = [statements_per_transaction, remaining / rows_per_statement].min
    params = count == statements_per_transaction ? chunk : Array.new(count, full_params)
    batcher.add(count * rows_per_statement) { db.batch_execute(full_sql, params) }
    remaining -= count * rows_per_statement
  end

  if remaining > 0
    rem_stmt = db.prepare(multi_row_sql(remaining))
    batcher.add(remaining) { rem_stmt.execute(USER * remaining) }
    rem_stmt.close
  end

  batcher.finish
  db.close
end

LABEL_WIDTH = 28

def benchmark(label)
  print "#{label.ljust(LABEL_WIDTH)} ..."
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  seconds = finish - start
  rows_per_sec = with_thousands((ROW_COUNT / seconds).round)
  printf("\r%s %9.4f s  %12s rows/s\n", label.ljust(LABEL_WIDTH), seconds, rows_per_sec)
end

puts "",
     "Benchmarking INSERT encodings (#{ROW_COUNT} rows, transaction size #{TRANSACTION_SIZE})",
     ""

with_db_path { |path| benchmark("per_row (status quo)") { write_per_row(path) } }
with_db_path { |path| benchmark("batch_execute") { write_batch_execute(path) } }

[5, 10, 25, 50, 100, 500, MAX_ROWS_PER_STATEMENT].each do |m|
  with_db_path { |path| benchmark("multi_row(#{m})") { write_multi_row(path, m) } }
end

[25, 100].each do |m|
  with_db_path { |path| benchmark("multi_row_batch(#{m})") { write_multi_row_batch(path, m) } }
end
