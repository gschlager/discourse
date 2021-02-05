#!/usr/bin/env ruby
# frozen_string_literal: true

require 'colored2'
require 'tty-spinner'

# A very simple implementation to make the spinner work without a working TTY
class DummySpinner
  def initialize(format: ":title... ", success_mark: "✓", error_mark: "✘")
    @format = format
    @success_mark = success_mark
    @error_mark = error_mark
  end

  def auto_spin
    text = @title ? @format.gsub(":title", @title) : @format
    print(text)
  end

  def update(title:)
    @title = title
  end

  def success
    puts(@success_mark)
  end

  def error
    puts(@error_mark)
  end
end

def create_spinner(show_warning_instead_of_error:)
  output = $stderr
  success_mark = "✓ ".bold
  error_mark = show_warning_instead_of_error ? "⚠ ".bold : "✘ ".bold

  if output.tty?
    if ENV['RM_INFO']
      DummySpinner.new(
        success_mark: "✓ DONE".green,
        error_mark: show_warning_instead_of_error ? "⚠ WARNING".yellow : "✘ ERROR".red
      )
    else
      TTY::Spinner.new(
        ":spinner :title",
        success_mark: success_mark.green,
        error_mark: show_warning_instead_of_error ? error_mark.yellow : error_mark.red,
        frames: TTY::Formats::FORMATS[:dots][:frames].map { |f| "#{f} " }
      )
    end
  else
    DummySpinner.new(
      success_mark: "✓ DONE",
      error_mark: show_warning_instead_of_error ? "⚠ WARNING" : "✘ ERROR"
    )
  end
end

@error_spinner = create_spinner(show_warning_instead_of_error: false)
@warning_spinner = create_spinner(show_warning_instead_of_error: true)

def spin(title, abort_on_error)
  result = nil

  spinner = abort_on_error ? @error_spinner : @warning_spinner
  spinner.update(title: title)
  spinner.auto_spin

  begin
    result = yield
    spinner.success
  rescue StandardError => e
    spinner.error
    raise if abort_on_error
  end

  # spinner.run do |s|
  #   begin
  #     result = yield(s)
  #     s.success
  #   rescue StandardError => e
  #     s.error
  #     raise if abort_on_error
  #   end
  # end

  result
end

def log(message, abort_on_error: false)
  spin(message, abort_on_error) do
    yield
  end
end

log("Downloading backup") do
  sleep(2)
end

log("Decompressing backup") do
  sleep(2)
end

log("Validating metadata") do
  sleep(2)
  raise "it failed"
end

puts "foo bar"

log("Restoring database", abort_on_error: true) do
  sleep(3)
  raise "it failed"
end

puts "Done"
