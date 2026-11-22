# An invitation to administer a school. See "Invitations" in ../../architecture.md.
class CreateInvitations < ActiveRecord::Migration[8.1]
  include TenantTables

  def change
    create_tenant_table :invitations do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false
      # The inviter: an admin, or an operator for onboarding (for example, "Ops: Avery Lin, ticket ONB-42").
      t.string :operator_reference
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      # Part of the token. Resend and revoke change it, so older links stop working.
      t.integer :lock_version, null: false, default: 0
    end
    add_tenant_reference :invitations, :school
    add_tenant_reference :invitations, :invited_by_user, to_table: :users, null: true
    add_check_constraint :invitations, "role IN ('admin', 'assistant_admin')", name: "invitations_role"
    add_check_constraint :invitations, "num_nonnulls(invited_by_user_id, operator_reference) = 1",
                         name: "invitations_one_inviter"
    # One open invitation for each person and school. Reason: a repeated request does not send a second email.
    add_index :invitations, [ :organization_id, :school_id, :email ], unique: true,
                                                                       where: "accepted_at IS NULL AND revoked_at IS NULL",
                                                                       name: "index_invitations_one_open"
  end
end
