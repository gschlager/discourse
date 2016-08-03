require 'yaml'
require_relative '../lib/version'

MIN_VERSION = Gem::Version.new('1.0')
CHANGES_YML = File.expand_path('../config/site_setting_changes.yml', File.dirname(__FILE__))

class SettingsUpdater
  def initialize
    @renamed_setting_names = load_renamed_setting_names
  end

  def execute
    previous_settings = Hash.new
    changes = Hash.new

    get_stable_git_tags.each do |(tag, version)|
      current_settings = get_settings_with_values(load_site_settings(tag))

      if version > MIN_VERSION
        changed_setting_names = get_changed_setting_names(previous_settings, current_settings)
        changes[version.to_s] = changed_setting_names unless changed_setting_names.empty?
      end

      previous_settings = current_settings
    end

    write_changed_setting_names(changes)
  end

  private

  def load_renamed_setting_names
    yaml = YAML.load_file(CHANGES_YML)
    yaml['renames'] || Hash.new
  end

  def get_stable_git_tags
    current_version = Gem::Version.new(Discourse::VERSION::STRING.chomp(".#{Discourse::VERSION::PRE}"))

    `git tag -l`
      .split("\n")
      .select { |tag| tag.start_with?('v') && !tag.include?('beta') }
      .map { |tag| Gem::Version.new(tag[1..-1]) }
      .select { |version| version >= MIN_VERSION && version <= current_version }
      .sort
      .map { |version| ["v#{version.to_s}", version] }
      .push(['HEAD', current_version])
  end

  def load_site_settings(tag)
    settings = `git show #{tag}:config/site_settings.yml`
    YAML.load(settings)
  end

  def get_settings_with_values(yaml)
    current_settings = Hash.new

    yaml.each_key do |category|
      yaml[category].each do |setting_name, value|
        full_setting_name = "#{category}.#{setting_name}"
        value = value['default'] if value.is_a?(Hash)

        current_settings[full_setting_name] = value
      end
    end

    current_settings
  end

  def get_changed_setting_names(previous_settings, current_settings)
    added_setting_names = find_new_setting_names(previous_settings, current_settings)
    changed_setting_names = find_changed_setting_names(previous_settings, current_settings)

    changes = Hash.new
    changes['added'] = added_setting_names unless added_setting_names.empty?
    changes['changed'] = changed_setting_names unless changed_setting_names.empty?

    changes
  end

  def find_new_setting_names(previous_settings, current_settings)
    current_setting_names = current_settings.keys.sort
    previous_setting_names = previous_settings.keys.sort

    added_setting_names = current_setting_names - previous_setting_names
    removed_setting_names = previous_setting_names - current_setting_names
    discard_renamed_setting_names(added_setting_names, removed_setting_names)

    added_setting_names
  end

  def discard_renamed_setting_names(added_setting_names, removed_setting_names)
    removed_setting_names.each do |old_setting_name|
      if @renamed_setting_names.has_key?(old_setting_name)
        new_setting_name = @renamed_setting_names[old_setting_name]
        added_setting_names.delete(new_setting_name)
      end
    end
  end

  def find_changed_setting_names(previous_settings, current_settings)
    changed_setting_names = []

    current_settings.each do |setting_name, value|
      if previous_settings.has_key?(setting_name) && previous_settings[setting_name] != value
        changed_setting_names.push(setting_name)
      end
    end

    changed_setting_names
  end

  def write_changed_setting_names(changes)
    output = {
      'renames' => @renamed_setting_names,
      'changes' => changes
    }

    File.open(CHANGES_YML, 'w') do |file|
      file.write(output.to_yaml)
    end
  end
end

SettingsUpdater.new.execute
