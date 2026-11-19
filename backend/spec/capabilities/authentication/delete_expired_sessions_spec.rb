require "rails_helper"

# Ended sessions are deleted, so the sessions table holds only sessions that can still be used.
RSpec.describe Authentication::DeleteExpiredSessions do
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:now) { Time.zone.parse("2026-11-19 12:00:00") }

  it "deletes sessions that have ended, and keeps the others" do
    ended = Session.create!(identity:, expires_at: now - 1.minute)
    ends_now = Session.create!(identity:, expires_at: now)
    active = Session.create!(identity:, expires_at: now + 1.minute)

    result = described_class.call(as_of: now)

    expect(result).to be_success
    expect(Session.where(id: [ ended.id, ends_now.id, active.id ]).pluck(:id)).to eq([ active.id ])
  end
end
