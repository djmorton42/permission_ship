# Tasks for the operations team.
namespace :onboarding do
  # For a school without a board administrator. The audit event names the operator.
  #   bin/rails onboarding:invite_school_admin ORGANIZATION_ID=... SCHOOL_ID=... \
  #     EMAIL=... NAME="..." OPERATOR="Ops: Avery Lin, ticket ONB-42"
  desc "Invite a school's first admin. ORGANIZATION_ID, SCHOOL_ID, EMAIL, NAME, OPERATOR (your name and the ticket)"
  task invite_school_admin: :environment do
    inputs = { organization_id: "ORGANIZATION_ID", school_id: "SCHOOL_ID", email: "EMAIL", name: "NAME",
               operator_reference: "OPERATOR" }.transform_values { ENV.fetch(it) }
    result = Accounts::InviteAdministrator.call(**inputs, role: "admin")
    raise "Not invited: #{result.errors.map(&:to_h)}" if result.failure?

    puts "Invited #{inputs[:email]}. Invitation #{result.value}."
  end
end
