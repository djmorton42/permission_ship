# An admin manages the school's administrators. An assistant admin does the other administration tasks.
class AddRoleToSchoolAdministrators < ActiveRecord::Migration[8.1]
  def change
    # Existing administrators become admins. New rows must give a role.
    add_column :school_administrators, :role, :string, null: false, default: "admin"
    change_column_default :school_administrators, :role, from: "admin", to: nil
    add_check_constraint :school_administrators, "role IN ('admin', 'assistant_admin')",
                         name: "school_administrators_role"
  end
end
