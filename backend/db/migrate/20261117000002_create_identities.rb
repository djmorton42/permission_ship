class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :identities, :email, unique: true
    add_check_constraint :identities, "email = lower(email)", name: "identities_email_lowercase"
  end
end
