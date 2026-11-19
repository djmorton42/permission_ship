require "rails_helper"

# A request restarts the idle timeout of its own session only. Another person's requests
# must not keep a session alive, for example one left open on a shared computer.
RSpec.describe Authentication::RecordSessionActivity do
  let(:zadok) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:barnabas) { create_identity(email: "barnabas.marsh@innsmouth.example", password: "another password") }
  let(:now) { Time.zone.parse("2026-11-19 12:00:00") }

  it "restarts the idle timeout of the given session, and of no other session" do
    left_open = Session.create!(identity: zadok, expires_at: now + 1.hour, last_active_at: now - 20.minutes)
    in_use = Session.create!(identity: barnabas, expires_at: now + 1.hour, last_active_at: now - 20.minutes)

    result = described_class.call(session_id: in_use.id, as_of: now)

    expect(result).to be_success
    expect(in_use.reload.last_active_at).to eq(now)
    expect(left_open.reload.last_active_at).to eq(now - 20.minutes)
  end
end
