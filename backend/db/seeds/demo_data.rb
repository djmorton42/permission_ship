# Demo school boards, schools and school administrators (from etc/demo-school-data.txt).
# DemoData.load is idempotent. Every administrator logs in with DEMO_PASSWORD.
# This file has no side effects. db/seeds/demo.rb loads the data. In development,
# the login page lists the logins (Api::V1::Development::DemoAccountsController).
#
# These writes do not use commands, because the commands to create organizations,
# schools and users do not exist yet (see todo.md).
module DemoData
  DEMO_PASSWORD = "permishly-demo".freeze

  # Board => { time_zone:, email_domain:, schools: { school name => administrator name } }
  BOARDS = {
    "Eldritch Shores Board of Education" => {
      time_zone: "America/New_York", email_domain: "eldritch-shores.example",
      schools: {
        "Innsmouth Heights Secondary School" => "Marsha Deepwater",
        "Unknowable Horizons Academy" => "Ida Fathom",
        "The School Beyond the Pines" => "Silas Pine"
      }
    },
    "Central Directorate of Approved Learning" => {
      time_zone: "America/Chicago", email_domain: "central-directorate.example",
      schools: {
        "Compliance Collegiate" => "Prudence Form",
        "Designated Learning Facility 7" => "Rex Ledger",
        "Bright Future Academy" => "Hope Sunnyvale"
      }
    },
    "United Realms District School Board" => {
      time_zone: "America/Toronto", email_domain: "united-realms.example",
      schools: {
        "Quest Preparatory Academy" => "Gwendolyn Brightshield",
        "Wyvern Heights Secondary School" => "Tobias Emberwing",
        "The Royal School of Mostly Safe Spells" => "Mabel Fizzwick"
      }
    }
  }.freeze

  # One person who administers schools in two boards, to show the organization picker.
  TWO_BOARD_ADMINISTRATOR = {
    name: "Morgan Crossway", email: "morgan.crossway@example.com",
    schools: { "Central Directorate of Approved Learning" => "Bright Future Academy",
               "United Realms District School Board" => "Quest Preparatory Academy" }
  }.freeze

  def self.load
    BOARDS.each do |board_name, board|
      organization = Organization.find_or_create_by!(name: board_name)
      Tenancy.with_organization(organization) do
        board[:schools].each do |school_name, admin_name|
          school = School.find_or_create_by!(organization:, name: school_name) { it.time_zone = board[:time_zone] }
          add_administrator(organization:, school:, name: admin_name, identity: identity(email(admin_name, board)))
        end
      end
    end

    two_board_identity = identity(TWO_BOARD_ADMINISTRATOR[:email])
    TWO_BOARD_ADMINISTRATOR[:schools].each do |board_name, school_name|
      organization = Organization.find_by!(name: board_name)
      Tenancy.with_organization(organization) do
        school = School.find_by!(name: school_name)
        add_administrator(organization:, school:, name: TWO_BOARD_ADMINISTRATOR[:name], identity: two_board_identity)
      end
    end
  end

  # The demo boards, their schools, and each school's administrators with their login email.
  def self.directory
    BOARDS.map do |board_name, board|
      schools = board[:schools].map do |school_name, admin_name|
        administrators = [ { name: admin_name, email: email(admin_name, board) } ]
        if TWO_BOARD_ADMINISTRATOR[:schools][board_name] == school_name
          administrators << TWO_BOARD_ADMINISTRATOR.slice(:name, :email)
        end
        { name: school_name, administrators: }
      end
      { name: board_name, schools: }
    end
  end

  def self.email(name, board)
    "#{name.downcase.tr(' ', '.')}@#{board[:email_domain]}"
  end

  def self.identity(email)
    Identity.find_or_create_by!(email:) { it.password = DEMO_PASSWORD }
  end

  def self.add_administrator(organization:, school:, name:, identity:)
    user = User.find_or_create_by!(organization:, identity:) { it.name = name }
    SchoolAdministrator.find_or_create_by!(organization:, school:, user:) { it.role = "admin" }
  end
end
