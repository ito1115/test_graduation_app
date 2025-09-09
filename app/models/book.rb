class Book < ApplicationRecord
  belongs_to :user
  has_many :notifications, dependent: :destroy

  enum reading_status: {
    wish: 0,        # 読みたい
    tsundoku: 1,    # 積読
    completed: 2    # 読了
  }

  # 状態変更時の日付を自動記録
  before_save :update_status_dates
  # 空文字列をnilに変換してユニーク制約エラーを防ぐ
  before_save :normalize_isbn_fields
  
  validates :title, presence: true, length: { maximum: 500 }
  validates :purchase_reason, presence: true, length: { maximum: 1000 }
  validates :purchase_date, presence: true
  validates :reading_status, presence: true
  
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
  scope :tsundoku, -> { where(reading_status: :tsundoku) }
  
  # 推薦ロジック用スコープ
  scope :for_recommendation, ->(user, exclude_recent_days: 30) {
    tsundoku
      .by_user(user)
      .where.not(
        id: recent_recommended_book_ids(user, exclude_recent_days)
      )
  }
  
  scope :older_tsundoku_first, -> {
    order(:tsundoku_date, :created_at)
  }
  
  # Google Books API連携メソッド
  class << self
    # 最近推薦された本のIDを取得
    def recent_recommended_book_ids(user, days = 30)
      Notification.for_user(user)
                  .where(sent_at: days.days.ago..Time.current)
                  .pluck(:book_id)
                  .compact
    end
    
    # 推薦本を選択（改良版）
    def select_recommendation_book(user)
      candidates = for_recommendation(user)
      
      return nil if candidates.empty?
      
      # 積読期間に基づく重み付け選択
      weighted_selection(candidates)
    end
    
    private
    
    # 積読期間による重み付けランダム選択
    def weighted_selection(books)
      return books.first if books.count == 1
      
      # 積読期間が長いほど重みを大きく
      weighted_books = books.map do |book|
        days_since_tsundoku = book.tsundoku_date ? 
          (Time.current - book.tsundoku_date) / 1.day : 
          0
        weight = [days_since_tsundoku, 1].max  # 最低重み1
        
        { book: book, weight: weight }
      end
      
      # 重み付きランダム選択
      total_weight = weighted_books.sum { |item| item[:weight] }
      random_value = rand * total_weight
      
      cumulative_weight = 0
      weighted_books.each do |item|
        cumulative_weight += item[:weight]
        return item[:book] if random_value <= cumulative_weight
      end
      
      # フォールバック
      books.sample
    end
    
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
    
    def search_google_books_by_title(title, author: nil, max_results: nil)
      GoogleBooksService.search_by_title(title, author: author, max_results: max_results)
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
        google_books_id: data[:google_books_id],
        purchase_reason: data[:purchase_reason] || 'Added from Google Books',
        purchase_date: data[:purchase_date] || Date.current
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

  private

  def update_status_dates
    return unless reading_status_changed?
    
    case reading_status
    when 'wish'
      self.wish_date = Time.current
    when 'tsundoku'
      self.tsundoku_date = Time.current
    when 'completed'
      self.completed_date = Time.current
    end
  end

  def normalize_isbn_fields
    self.isbn_10 = nil if isbn_10.blank?
    self.isbn_13 = nil if isbn_13.blank?
    self.google_books_id = nil if google_books_id.blank?
  end
end