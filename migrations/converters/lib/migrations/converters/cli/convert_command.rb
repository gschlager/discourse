# frozen_string_literal: true

module Migrations
  module Converters
    module CLI
      class ConvertCommand < Migrations::CLI::Command
        class Error < StandardError
          include Migrations::CLI::PresentableError
        end

        self.description = "Convert a source dump into the IntermediateDB"

        option "--settings", "PATH", "Path of the settings file."
        option "--reset", :flag, "Reset the database before converting data."
        option "--only",
               "STEPS",
               "Run only the specified steps (comma-separated).",
               default: [] do |value|
          STEP_LIST.call(value)
        end
        option "--skip",
               "STEPS",
               "Skip the specified steps (comma-separated).",
               default: [] do |value|
          STEP_LIST.call(value)
        end

        # Optional at the parser level so a missing value produces our own
        # message (with the list of valid converters) rather than Clamp's
        # generic "no value provided".
        parameter "[CONVERTER_TYPE]", "The converter to run (e.g. discourse)."

        def execute
          if converter_type.nil?
            raise Error, "Missing required argument: <converter_type>\n#{valid_names_message}"
          end

          type = converter_type.downcase
          validate_converter_type!(type)

          settings = load_settings(type)

          Database.reset!(settings[:intermediate_db][:path]) if reset?

          converter = "migrations/converters/#{type}/converter".camelize.constantize
          converter.new(settings).run(only_steps: only, skip_steps: skip)
        end

        private

        def validate_converter_type!(type)
          return if Converters.names.include?(type)

          raise Error, <<~MSG
            Unknown converter name: #{type}
            #{valid_names_message}
          MSG
        end

        def valid_names_message
          "Valid names are: #{Converters.names.join(", ")}"
        end

        def load_settings(type)
          settings_path = settings || Converters.default_settings_path(type)
          settings_path = File.expand_path(settings_path, Dir.pwd)

          raise Error, "Settings file not found: #{settings_path}" unless File.exist?(settings_path)

          YAML.safe_load(File.read(settings_path), symbolize_names: true)
        end
      end
    end
  end
end
