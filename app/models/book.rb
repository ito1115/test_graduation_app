class Book < ApplicationRecord
  belongs_to :user
  has_many :notifications, dependent: :destroy
  
  validates :title, presence: true, length: { maximum: 500 }
  validates :purchase_reason, presence: true, length: { maximum: 1000 }
  validates :purchase_date, presence: true
  
  # Google Books API関連フィールド（オプショナル）
  validates :author, length: { maximum: 500 }
  validates :publisher, length: { maximum: 255 }
  validates :published_date, length: { maximum: 50 }
  validates :description, length: { maximum: 5000 }
  validates :isbn_10, length: { maximum: 10 }, uniqueness: { allow_blank: true }
  validates :isbn_13, length: { maximum: 13 }, uniqueness: { allow_blank: true }
  validates :image_url, length: { maximum: 1000 }
  validates :google_books_id, length: { maximum: 100 }, uniqueness: { allow_blank: true }
  
  scope :by_user, ->(user) { where(user: user) }
  scope :search_by_title, ->(query) { where("title ILIKE ?", "%#{query}%") }
  scope :search_by_author, ->(query) { where("author ILIKE ?", "%#{query}%") }
  scope :with_google_books_id, -> { where.not(google_books_id: [nil, ""]) }
  
  # Google Books API連携メソッド
  class << self
    def create_from_isbn(user:, isbn:)
      results = GoogleBooksService.search_by_isbn(isbn)
      return nil if results.nil? || results.empty?
      
      book_data = results.first
      create_from_google_books_data(user: user, data: book_data)
    end
    
    def create_from_google_books_id(user:, google_books_id:)
      book_data = GoogleBooksService.get_book_by_id(google_books_id)
      return nil unless book_data
      
      create_from_google_books_data(user: user, data: book_data)
    end
    
    def search_google_books_by_isbn(isbn)
      GoogleBooksService.search_by_isbn(isbn)
    end
    
    def search_google_books_by_title(title, author: nil)
      GoogleBooksService.search_by_title(title, author: author)
    end
    
    def create_from_google_books_data(user:, data:)
      # 既存の本をGoogle Books IDまたはISBNで検索
      existing_book = find_existing_book_by_identifiers(user, data)
      return existing_book if existing_book
      
      create!(
        user: user,
        title: data[:title] || 'Unknown Title',
        author: data[:author],
        publisher: data[:publisher],
        published_date: data[:published_date],
        description: data[:description],
        isbn_10: data[:isbn_10],
        isbn_13: data[:isbn_13],
        image_url: data[:image_url],
        google_books_id: data[:google_books_id]
      )
    end
    
    private
    
    def find_existing_book_by_identifiers(user, data)
      # Google Books IDで検索
      if data[:google_books_id].present?
        book = by_user(user).find_by(google_books_id: data[:google_books_id])
        return book if book
      end
      
      # ISBN-13で検索
      if data[:isbn_13].present?
        book = by_user(user).find_by(isbn_13: data[:isbn_13])
        return book if book
      end
      
      # ISBN-10で検索
      if data[:isbn_10].present?
        book = by_user(user).find_by(isbn_10: data[:isbn_10])
        return book if book
      end
      
      nil
    end
  end
  
  def authors_array
    author&.split(',')&.map(&:strip) || []
  end
  
  def primary_isbn
    isbn_13.presence || isbn_10.presence
  end
  
  def refresh_from_google_books!
    return false unless google_books_id.present?
    
    book_data = GoogleBooksService.get_book_by_id(google_books_id)
    return false unless book_data
    
    update!(
      title: book_data[:title] || title,
      author: book_data[:author] || author,
      publisher: book_data[:publisher] || publisher,
      published_date: book_data[:published_date] || published_date,
      description: book_data[:description] || description,
      isbn_10: book_data[:isbn_10] || isbn_10,
      isbn_13: book_data[:isbn_13] || isbn_13,
      image_url: book_data[:image_url] || image_url
    )
    
    true
  rescue => e
    Rails.logger.error "Failed to refresh book from Google Books: #{e.message}"
    false
  end
end