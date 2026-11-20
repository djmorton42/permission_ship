# typed: false

require "rails_helper"

RSpec.describe Authentication::DeleteExpiredSessionsJob do
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }

  it "deletes the sessions that have ended" do
    ended = Session.create!(identity:, expires_at: 1.minute.ago, last_active_at: 2.minutes.ago)
    active = Session.create!(identity:, expires_at: 1.minute.from_now, last_active_at: 2.minutes.ago)

    described_class.perform_now

    expect(Session.where(id: [ ended.id, active.id ]).pluck(:id)).to eq([ active.id ])
  end

  it "runs on the low queue" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue("low")
  end
end
