# travel_to, travel and freeze_time. Specs control time with these, not the real clock.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end
