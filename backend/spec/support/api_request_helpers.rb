# typed: false

# Write requests as the React app sends them: JSON, from the app's own origin.
# The API rejects other writes. See "Sessions and CSRF" in architecture.md.
module ApiRequestHelpers
  # The origin of request specs (the default integration test host).
  OWN_ORIGIN = "http://www.example.com".freeze

  def api_post(path, params = {})
    post(path, params:, as: :json, headers: { "Origin" => OWN_ORIGIN })
  end

  def api_patch(path, params = {})
    patch(path, params:, as: :json, headers: { "Origin" => OWN_ORIGIN })
  end

  def api_delete(path)
    delete(path, headers: { "Origin" => OWN_ORIGIN })
  end
end

RSpec.configure do |config|
  config.include ApiRequestHelpers, type: :request
end
