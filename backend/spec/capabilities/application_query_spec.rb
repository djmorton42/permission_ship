# typed: false

require "rails_helper"

RSpec.describe ApplicationQuery do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }

  let(:school_names) do
    stub_const("TestQuery", Class.new(ApplicationQuery) do
      def perform = success(School.order(:name).pluck(:name))
    end)
  end

  before do
    in_organization(eldritch) { School.create!(organization: eldritch, name: "The School Beyond the Pines", time_zone: "America/New_York") }
    in_organization(realms) { School.create!(organization: realms, name: "Wyvern Heights Secondary School", time_zone: "America/Toronto") }
  end

  it "reads only the given organization's rows" do
    expect(school_names.call(organization_id: eldritch.id).value).to eq([ "The School Beyond the Pines" ])
  end

  it "requires an organization" do
    expect(school_names.call.category).to eq(:validation)
  end

  it "does not write" do
    sneaky = stub_const("TestQuery", Class.new(ApplicationQuery) do
      def perform = success(School.update_all(name: "Renamed"))
    end)

    expect { sneaky.call(organization_id: eldritch.id) }.to raise_error(ActiveRecord::ReadOnlyError)
    expect(in_organization(eldritch) { School.pluck(:name) }).to eq([ "The School Beyond the Pines" ])
  end
end

# Outside the spec's wrapping transaction, so the query opens its own.
RSpec.describe ApplicationQuery, "transaction" do
  self.use_transactional_tests = false

  it "runs in a read-only transaction" do
    read_only_setting = stub_const("TestQuery", Class.new(ApplicationQuery) do
      runs_without_organization

      def perform = success(ApplicationRecord.connection.select_value("SHOW transaction_read_only"))
    end)

    expect(read_only_setting.call.value).to eq("on")
  end
end
