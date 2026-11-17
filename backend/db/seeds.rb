# Records every environment needs. Must be idempotent (bin/rails db:seed can run at any time).
# Demo data (development only) is in db/seeds/demo.rb.

load Rails.root.join("db/seeds/demo.rb") if Rails.env.development?
