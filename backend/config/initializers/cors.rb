# typed: false

# Rack::Cors evaluates the blocks with its DSL, so Sorbet cannot see the methods.

# Be sure to restart your server when you modify this file.
#
# In development the Vite dev server proxies /api to Rails, so the browser
# sees a single origin and CORS isn't needed. These rules cover cases where
# the frontend is served from a different origin (e.g. a CDN in production).
# The origins are config.x.allowed_origins (config/application.rb). With no
# origins, no CORS headers are sent, so other origins cannot read responses.
#
# Read more: https://github.com/cyu/rack-cors

origins = Rails.application.config.x.allowed_origins

if origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*origins)

      resource "/api/*",
        headers: :any,
        methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
        credentials: true
    end
  end
end
