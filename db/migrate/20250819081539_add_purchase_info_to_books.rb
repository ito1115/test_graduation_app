class AddPurchaseInfoToBooks < ActiveRecord::Migration[7.1]
  def change
    add_column :books, :purchase_reason, :text
    add_column :books, :purchase_date, :date
  end
end
