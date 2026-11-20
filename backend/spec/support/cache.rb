# typed: false

# The test cache is a memory store, so rate limits count in specs.
# Clear it, so counts from one example do not reach the next.
RSpec.configure do |config|
  config.before { Rails.cache.clear }
end
