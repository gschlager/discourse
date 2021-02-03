# frozen_string_literal: true

require 'colored2'
require 'tty-spinner'

module DiscourseCLI
  # A very simple implementation to make the spinner work without a working TTY
  class DummySpinner
    def initialize(format: ":title... ", success_mark: "✓", error_mark: "✗")
      @format = format
      @success_mark = success_mark
      @error_mark = error_mark
    end

    def run
      text = @title ? @format.gsub(":title", @title) : @format
      print(text)

      begin
        yield(self)
      rescue
        @success = false
        raise
      end

      puts(@success ? @success_mark : @error_mark)
    end

    def update(title:)
      @title = title
    end

    def success
      @success = true
    end

    def error
      @success = false
    end
  end

  module HasSpinner
    private

    def spinner
      @spinner ||= begin
        output = $stderr
        success_mark = "✓"
        error_mark = "✗"

        if output.tty?
          success_mark = success_mark.green
          error_mark = error_mark.red
        end

        if !output.tty? || ENV['RM_INFO']
          DummySpinner.new(
            success_mark: "#{success_mark} DONE",
            error_mark: "#{error_mark} ERROR"
          )
        else
          TTY::Spinner.new(
            "[:spinner] :title",
            success_mark: success_mark,
            error_mark: error_mark
          )
        end
      end
    end

    def spin(title)
      result = nil

      spinner.update(title: title)
      spinner.run do |s|
        begin
          result = yield(s)
          s.success
        rescue StandardError => e
          s.error
        end
      end

      result
    end
  end
end
