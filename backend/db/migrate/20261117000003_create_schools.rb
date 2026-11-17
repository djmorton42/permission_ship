class CreateSchools < ActiveRecord::Migration[8.1]
  include TenantTables

  def change
    create_tenant_table :schools do |t|
      t.string :name, null: false
      t.string :time_zone, null: false
    end
  end
end
