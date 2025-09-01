class MakeBookIdRequiredInNotifications < ActiveRecord::Migration[7.1]
  def up
    # 既存のbook_idがNULLのレコードがある場合は事前に削除または更新が必要
    # Notification.where(book_id: nil).delete_all
    
    # book_idをNULL不許可に変更
    change_column_null :notifications, :book_id, false
  end
  
  def down
    # book_idをNULL許可に戻す
    change_column_null :notifications, :book_id, true
  end
end