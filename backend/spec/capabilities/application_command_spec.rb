require "rails_helper"

RSpec.describe ApplicationCommand do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }

  # Opens a school. Rejects names that the board has banned.
  let(:open_school) do
    Class.new(ApplicationCommand) do
      def self.name = "TestCommand"
      attribute :name, :string
      attribute :banned_name, :string
      validates :name, presence: true

      def perform
        school = School.create!(organization_id:, name:, time_zone: "America/Toronto")
        return failure(:validation, field: :name, code: "banned", message: "is banned") if name == banned_name

        success(school.id)
      end
    end
  end

  def school_names(organization) = in_organization(organization) { School.order(:name).pluck(:name) }

  it "writes in the given organization and returns the value" do
    result = open_school.call(organization_id: eldritch.id, name: "Unknowable Horizons Academy")

    expect(result).to be_success
    expect(school_names(eldritch)).to eq([ "Unknowable Horizons Academy" ])
    expect(school_names(realms)).to eq([])
    expect(in_organization(eldritch) { School.find(result.value).name }).to eq("Unknowable Horizons Academy")
  end

  it "returns a validation failure and writes nothing when the input is not valid" do
    result = open_school.call(organization_id: eldritch.id, name: "")

    expect(result).to be_failure
    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:to_h)).to eq([ { field: "name", code: "blank", message: "can't be blank" } ])
    expect(school_names(eldritch)).to eq([])
  end

  it "requires an organization" do
    result = open_school.call(name: "Unknowable Horizons Academy")

    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:field)).to eq([ "organization_id" ])
  end

  it "rolls back its writes when it returns a failure" do
    result = open_school.call(organization_id: eldritch.id, name: "Ghoul Academy", banned_name: "Ghoul Academy")

    expect(result.errors.map(&:to_h)).to eq([ { field: "name", code: "banned", message: "is banned" } ])
    expect(school_names(eldritch)).to eq([])
  end

  it "clears the organization when it ends" do
    open_school.call(organization_id: eldritch.id, name: "Unknowable Horizons Academy")

    expect(School.count).to eq(0)
  end

  it "can run without an organization when it declares that" do
    rename_board = Class.new(ApplicationCommand) do
      def self.name = "TestCommand"
      runs_without_organization
      attribute :name, :string

      def perform
        success(Organization.create!(name:).id)
      end
    end

    result = rename_board.call(name: "Central Directorate of Approved Learning")

    expect(Organization.find(result.value).name).to eq("Central Directorate of Approved Learning")
  end

  it "uses a dependency default unless the caller passes one" do
    greet = Class.new(ApplicationCommand) do
      def self.name = "TestCommand"
      runs_without_organization
      dependency :greeting, default: -> { "Hello" }

      def perform = success(greeting)
    end

    expect(greet.call.value).to eq("Hello")
    expect(greet.call({}, greeting: "Ia!").value).to eq("Ia!")
  end
end
