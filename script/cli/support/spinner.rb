# frozen_string_literal: true

require 'colored2'
require 'tty-spinner'

module DiscourseCLI
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

  module HasSpinner
    protected

    def spin(title, abort_on_error)
      result = nil

      spinner = abort_on_error ? error_spinner : warning_spinner
      spinner.update(title: title)
      spinner.auto_spin

      begin
        result = yield
        spinner.success
      rescue Exception
        spinner.error
        raise if abort_on_error
      end

      result
    end

    def error_spinner
      @error_spinner ||= create_spinner(show_warning_instead_of_error: false)
    end

    def warning_spinner
      @warning_spinner ||= create_spinner(show_warning_instead_of_error: true)
    end

    def create_spinner(show_warning_instead_of_error:)
      output = $stderr
      success_mark = " ✓ "
      error_mark = show_warning_instead_of_error ? " ⚠ " : " ✘ "

      if output.tty?
        if ENV['RM_INFO']
          DummySpinner.new(
            success_mark: "✓ DONE".green,
            error_mark: show_warning_instead_of_error ? "⚠ WARNING".yellow : "✘ ERROR".red
          )
        else
          TTY::Spinner.new(
            ":spinner :title",
            success_mark: " DONE ".green,
            error_mark: show_warning_instead_of_error ? " WARN ".yellow : " FAIL ".red,
            interval: 10,
            frames: [
              " ●    ",
              "  ●   ",
              "   ●  ",
              "    ● ",
              "     ●",
              "    ● ",
              "   ●  ",
              "  ●   ",
              " ●    ",
              "●     "
            ]
          )
        end
      else
        DummySpinner.new(
          success_mark: "✓ DONE",
          error_mark: show_warning_instead_of_error ? "⚠ WARNING" : "✘ ERROR"
        )
      end
    end
  end
end
