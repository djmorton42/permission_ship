# typed: false

require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  it "returns ok with dependency status" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["status"]).to eq("ok")
    expect(body["database"]).to be(true)
  end
end
