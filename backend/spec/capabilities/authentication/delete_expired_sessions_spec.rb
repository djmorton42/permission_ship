# typed: false

require "rails_helper"

# Ended sessions are deleted, so the sessions table holds only sessions that can still be used.
RSpec.describe Authentication::DeleteExpiredSessions do
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:now) { Time.zone.parse("2026-11-19 12:00:00") }

  it "deletes sessions that have ended, and keeps the others" do
    ended = Session.create!(identity:, expires_at: now - 1.minute, last_active_at: now - 1.minute)
    ends_now = Session.create!(identity:, expires_at: now, last_active_at: now - 1.minute)
    active = Session.create!(identity:, expires_at: now + 1.minute, last_active_at: now - 1.minute)

    result = described_class.call(as_of: now)

    expect(result).to be_success
    expect(Session.where(id: [ ended.id, ends_now.id, active.id ]).pluck(:id)).to eq([ active.id ])
  end

  it "deletes sessions that were idle for 30 minutes, and keeps the others" do
    idle = Session.create!(identity:, expires_at: now + 1.hour, last_active_at: now - 30.minutes)
    recent = Session.create!(identity:, expires_at: now + 1.hour, last_active_at: now - 29.minutes)

    described_class.call(as_of: now)

    expect(Session.where(id: [ idle.id, recent.id ]).pluck(:id)).to eq([ recent.id ])
  end
end
