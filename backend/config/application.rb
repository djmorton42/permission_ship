require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Permishly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Login uses a signed session cookie. API-only apps leave out the cookie middleware.
    config.middleware.use ActionDispatch::Cookies

    # Browser origins, other than the API's own, that may call the API with cookies.
    # CORS allows them, and writes from any other origin are rejected (CrossSiteRequestProtection).
    # Set CORS_ORIGINS (comma-separated). Production allows no other origin when it is not set.
    # Development and test allow the Vite dev server (5173) and the Playwright server (5174),
    # because the Vite proxy keeps the browser's Origin header.
    config.x.allowed_origins = ENV.fetch("CORS_ORIGINS") {
      Rails.env.production? ? "" : "http://localhost:5173,http://localhost:5174"
    }.split(",").map(&:strip).reject(&:empty?)

    # structure.sql stores row-level security policies. schema.rb cannot.
    config.active_record.schema_format = :sql

    # Loading stays explicit, and N+1 queries raise errors.
    config.active_record.strict_loading_by_default = true

    # Run Active Job on Solid Queue, stored in the primary database.
    # See "Background jobs" in ../architecture.md before writing jobs.
    config.active_job.queue_adapter = :solid_queue

    # Mission Control – Jobs dashboard at /jobs. It renders HTML, so it needs a
    # non-API base controller. HTTP basic auth stays closed until credentials
    # are set: bin/rails mission_control:jobs:authentication:configure
    config.mission_control.jobs.base_controller_class = "Admin::BaseController"

    # Generate RSpec specs and FactoryBot factories instead of Minitest files.
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
