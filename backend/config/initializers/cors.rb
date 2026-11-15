# Be sure to restart your server when you modify this file.
#
# In development the Vite dev server proxies /api to Rails, so the browser
# sees a single origin and CORS isn't needed. These rules cover cases where
# the frontend is served from a different origin (e.g. a CDN in production),
# configured via CORS_ORIGINS (comma-separated).
#
# Read more: https://github.com/cyu/rack-cors

origins = ENV.fetch("CORS_ORIGINS", "http://localhost:5173").split(",").map(&:strip)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*origins)

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
