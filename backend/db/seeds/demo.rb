# Demo data for development. See db/seeds/demo_data.rb.
require_relative "demo_data"

DemoData.load
puts "Demo data loaded. Administrators log in with the password #{DemoData::DEMO_PASSWORD.inspect}."
