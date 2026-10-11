class CreateQueues < ActiveRecord::Migration[8.1]
  def change
    create_table :queues do |t|
      t.string :name, null: false
      t.string :service_type, null: false
      t.integer :average_service_duration_minutes, null: false, default: 10
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_check_constraint :queues, 'average_service_duration_minutes > 0', name: 'queues_duration_positive'
    create_table :queue_tokens do |t|
      t.references :queue, null: false, foreign_key: true
      t.string :service_date, null: false
      t.integer :sequence_number, null: false
      t.string :token_number, null: false
      t.string :customer_name, null: false
      t.string :contact_number
      t.string :public_lookup_token, null: false
      t.string :service_type, null: false
      t.string :status, null: false, default: 'waiting'
      t.datetime :joined_at, null: false
      t.datetime :called_at
      t.datetime :service_started_at
      t.datetime :completed_at
      t.text :note
      t.timestamps
    end
    add_index :queue_tokens, %i[queue_id service_date sequence_number], unique: true, name: 'idx_queue_token_daily_sequence'
    add_index :queue_tokens, :public_lookup_token, unique: true
    add_index :queue_tokens, %i[queue_id service_date status joined_at]
    add_check_constraint :queue_tokens, "status IN ('waiting','serving','completed','skipped','cancelled')", name: 'queue_tokens_valid_status'
  end
end
