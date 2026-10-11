class AddStaffAuthAndVisitRequirements < ActiveRecord::Migration[8.1]
  def change
    add_column :queue_tokens, :visit_requirements, :text
    create_table :staff_users do |t|
      t.string :username, null: false
      t.string :display_name, null: false
      t.string :role, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :staff_users, 'lower(username)', unique: true, name: 'idx_staff_users_username_lower'
    add_check_constraint :staff_users, "role IN ('admin','doctor','receptionist')", name: 'staff_users_valid_role'
    create_table :staff_sessions do |t|
      t.references :staff_user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :staff_sessions, :token_digest, unique: true
    add_index :staff_sessions, :expires_at
  end
end
