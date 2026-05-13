require_relative "boot"
require "rails/all"
require_relative "../lib/fizzy"
require_relative "../lib/action_pack/railtie"

Bundler.require(*Rails.groups)

module Fizzy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Include the `lib` directory in autoload paths. Use the `ignore:` option
    # to list subdirectories that don't contain `.rb` files or that shouldn't
    # be reloaded or eager loaded.
    config.autoload_lib ignore: %w[ assets tasks rails_ext ]

    # Enable debug mode for Rails event logging so we get SQL query logs.
    # This was made necessary by the change in https://github.com/rails/rails/pull/55900
    config.after_initialize do
      Rails.event.debug_mode = true
    end

    # Use UUID primary keys for all new tables
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.action_pack.passkey.draw_routes = false
    config.action_pack.passkey.challenge_url = -> { my_passkey_challenge_path(script_name: "") }

    config.mission_control.jobs.http_basic_auth_enabled = false

    # PostgreSQL path: load PG-only migrations from db/postgresql_migrate/
    # (which lives OUTSIDE db/migrate/ so Rails' recursive `db/migrate/**`
    # globber doesn't pick them up under MySQL/SQLite) and dump
    # db/structure.sql instead of db/schema.rb (so tsvector/GIN survive).
    # MySQL/SQLite keep db/migrate/ + schema.rb untouched.
    if Fizzy.db_adapter.postgresql?
      config.paths["db/migrate"] = [ Rails.root.join("db/postgresql_migrate").to_s ]
      config.active_record.schema_format = :sql
    end
  end
end
