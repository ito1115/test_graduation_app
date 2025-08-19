class CreateBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author
      t.string :publisher
      t.string :published_date
      t.text :description
      t.string :isbn_10
      t.string :isbn_13
      t.string :image_url
      t.string :google_books_id
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :books, :title
    add_index :books, :author
    add_index :books, :isbn_10, unique: true
    add_index :books, :isbn_13, unique: true
    add_index :books, :google_books_id, unique: true
    add_index :books, [:user_id, :title]
  end
end