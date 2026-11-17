class CreateSchoolAdministrators < ActiveRecord::Migration[8.1]
  include TenantTables

  def change
    create_tenant_table :school_administrators
    add_tenant_reference :school_administrators, :school
    add_tenant_reference :school_administrators, :user
    add_index :school_administrators, [ :organization_id, :school_id, :user_id ], unique: true
  end
end
