# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "migrations-converters"
  s.version = "0.0.1"
  s.summary = "Discourse migrations: public converter implementations"
  s.authors = ["Discourse Team"]
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["lib/**/*"]

  s.add_dependency "migrations-core"
  s.add_dependency "activesupport"
  s.add_dependency "colored2"
  s.add_dependency "i18n"
  s.add_dependency "markbridge"
  s.add_dependency "pg"
  s.add_dependency "zeitwerk"

  # `mysql2` is an optional dependency, needed only by converters whose source is
  # MySQL/MariaDB (e.g. phpBB). It is loaded lazily by `Adapter::Mysql` so the gem
  # installs without MySQL client libraries; install it explicitly to use such a
  # converter.
end
