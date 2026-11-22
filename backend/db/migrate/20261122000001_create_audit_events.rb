# Who changed what, and when. See "Auditing" in ../../architecture.md.
# The app role cannot update or delete rows (db/privileges.sql).
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  include TenantTables

  def change
    create_tenant_table :audit_events do |t|
      # Operations work (for example, onboarding a school) has no user. It names the operator and a ticket.
      t.string :operator_reference
      t.string :action, null: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      # Changed attributes as { "attribute" => [before, after] }.
      t.jsonb :details, null: false, default: {}
    end
    add_tenant_reference :audit_events, :actor_user, to_table: :users, null: true
    add_index :audit_events, [ :organization_id, :subject_type, :subject_id ]
    add_check_constraint :audit_events, "num_nonnulls(actor_user_id, operator_reference) = 1",
                         name: "audit_events_one_actor"
  end
end
