# typed: false

require "rails_helper"
require Rails.root.join("db/seeds/demo_data").to_s

# The login page in development lists the demo logins from db/seeds/demo_data.rb.
RSpec.describe "Demo accounts (development only)", type: :request do
  def demo_accounts
    get "/api/v1/development/demo_accounts"
    response.parsed_body
  end

  it "lists each demo board with its schools and the administrators who log in to them" do
    body = demo_accounts

    expect(response).to have_http_status(:ok)
    expect(body["password"]).to eq("permishly-demo")
    expect(body["boards"].map { it["name"] }).to eq([
      "Eldritch Shores Board of Education",
      "Central Directorate of Approved Learning",
      "United Realms District School Board"
    ])
    expect(body["boards"].first).to eq(
      "name" => "Eldritch Shores Board of Education",
      "schools" => [
        { "name" => "Innsmouth Heights Secondary School",
          "administrators" => [ { "name" => "Marsha Deepwater", "email" => "marsha.deepwater@eldritch-shores.example" } ] },
        { "name" => "Unknowable Horizons Academy",
          "administrators" => [ { "name" => "Ida Fathom", "email" => "ida.fathom@eldritch-shores.example" } ] },
        { "name" => "The School Beyond the Pines",
          "administrators" => [ { "name" => "Silas Pine", "email" => "silas.pine@eldritch-shores.example" } ] }
      ]
    )
  end

  it "lists the administrator who is in two boards under a school in each board" do
    schools = demo_accounts["boards"].flat_map { it["schools"] }
    morgan = { "name" => "Morgan Crossway", "email" => "morgan.crossway@example.com" }

    expect(schools.select { it["administrators"].include?(morgan) }.map { it["name"] })
      .to eq([ "Bright Future Academy", "Quest Preparatory Academy" ])
  end

  it "lists only logins that work after the seeds load" do
    DemoData.load
    body = demo_accounts
    emails = body["boards"].flat_map { it["schools"] }.flat_map { it["administrators"] }.map { it["email"] }.uniq

    expect(emails.size).to eq(10)
    emails.each do |email|
      Rails.cache.clear # the login rate limit
      api_post "/api/v1/session", { email:, password: body["password"] }
      expect(response).to have_http_status(:no_content), "#{email} could not log in"
    end
  end

  it "is not available outside development and test" do
    allow(Rails.env).to receive(:local?).and_return(false)

    get "/api/v1/development/demo_accounts"

    expect(response).to have_http_status(:not_found)
  end
end
