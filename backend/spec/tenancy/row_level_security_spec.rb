# typed: false

require "rails_helper"

# Row-level security keeps each organization's data separate.
# These specs run as the app role (config/database.yml, primary).
RSpec.describe "Row-level security" do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }

  def connection = ApplicationRecord.connection

  it "runs specs as a role that row-level security applies to" do
    role = connection.select_one(
      "SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user"
    )
    expect(role).to eq("rolsuper" => false, "rolbypassrls" => false)
  end

  context "with schools in two organizations" do
    before do
      in_organization(eldritch) { School.create!(organization: eldritch, name: "Innsmouth Heights Secondary School", time_zone: "America/New_York") }
      in_organization(realms) { School.create!(organization: realms, name: "Quest Preparatory Academy", time_zone: "America/Toronto") }
    end

    it "shows only the current organization's rows" do
      names = in_organization(eldritch) { School.pluck(:name) }

      expect(names).to eq([ "Innsmouth Heights Secondary School" ])
    end

    it "shows no rows when no organization is set" do
      expect(School.count).to eq(0)
    end

    it "clears the organization when the block ends" do
      in_organization(eldritch) { School.count }

      expect(School.count).to eq(0)
    end

    # Rails turns on the query cache for each request. set_config must still run each time.
    it "sets the organization again in a second block, with the query cache on" do
      names = ApplicationRecord.cache do
        in_organization(eldritch) { School.count }
        in_organization(eldritch) { School.pluck(:name) }
      end

      expect(names).to eq([ "Innsmouth Heights Secondary School" ])
    end

    it "does not return another organization's cached rows, with the query cache on" do
      names = ApplicationRecord.cache do
        in_organization(eldritch) { School.pluck(:name) }
        in_organization(realms) { School.pluck(:name) }
      end

      expect(names).to eq([ "Quest Preparatory Academy" ])
    end

    it "restores the outer organization after a nested block" do
      names = in_organization(eldritch) do
        in_organization(realms) { School.count }
        School.pluck(:name)
      end

      expect(names).to eq([ "Innsmouth Heights Secondary School" ])
    end

    it "does not let a row refer to a row in another organization" do
      quest_id = in_organization(realms) { School.sole.id }
      expect {
        in_organization(eldritch) do
          identity = Identity.create!(email: "obed@example.com", password: "a long password")
          user = User.create!(organization: eldritch, identity:, name: "Obed Marsh")
          connection.transaction(requires_new: true) do
            connection.execute(ApplicationRecord.sanitize_sql_array([
              "INSERT INTO school_administrators (organization_id, school_id, user_id, role, created_at, updated_at) " \
              "VALUES (?, ?, ?, 'admin', now(), now())", eldritch.id, quest_id, user.id
            ]))
          end
        end
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  it "rejects a row for another organization" do
    expect {
      in_organization(eldritch) do
        School.create!(organization: realms, name: "Wyvern Heights Secondary School", time_zone: "America/Toronto")
      end
    }.to raise_error(ActiveRecord::StatementInvalid, /row-level security/)
  end
end
