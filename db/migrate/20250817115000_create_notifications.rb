class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: true, foreign_key: true
      t.string :notification_type, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    add_index :notifications, :notification_type
    add_index :notifications, :sent_at
    add_index :notifications, [:user_id, :notification_type]
    add_index :notifications, [:user_id, :sent_at]
    add_index :notifications, [:notification_type, :sent_at]
  end
end