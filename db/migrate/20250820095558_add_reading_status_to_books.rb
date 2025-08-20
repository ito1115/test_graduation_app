class AddReadingStatusToBooks < ActiveRecord::Migration[7.1]
  def change
    add_column :books, :reading_status, :integer
    add_column :books, :wish_date, :datetime
    add_column :books, :tsundoku_date, :datetime
    add_column :books, :completed_date, :datetime
  end
end
