# frozen_string_literal: true

require_relative '../support/spinner'
require 'thor'

module DiscourseCLI
  class Backup < Thor
    include HasSpinner

    desc "create", "Creates a backup"
    def create

    end

    desc "restore FILENAME", "Restores a backup"
    method_option :uploads, type: :boolean, default: true
    method_option :remap, type: :boolean, default: true
    method_option :rebake, type: :boolean, default: true
    method_option :interactive, type: :boolean, default: true
    method_option :path, type: :string, desc: "Overrides the backup location and looks for the backup file in this directory."
    def restore(filename)
      spin("Intitialize restore") do
        sleep(2)
      end

      spin("Restoring database") do
        sleep(2)
        raise "foo"
      end
    end

    desc "list", "Lists existing backups"
    def list

    end

    desc "delete", "Deletes a backup"
    def delete

    end

    desc "download", "Downloads a backup"
    def download

    end
  end
end
