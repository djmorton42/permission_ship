class CreateUsers < ActiveRecord::Migration[8.1]
  include TenantTables

  def change
    create_tenant_table :users do |t|
      t.references :identity, type: :uuid, null: false, foreign_key: true, index: false
      t.string :name, null: false
    end
    # A person has at most one user in each organization.
    add_index :users, [ :organization_id, :identity_id ], unique: true
    # Login lists an identity's organizations.
    add_index :users, :identity_id
  end
end
