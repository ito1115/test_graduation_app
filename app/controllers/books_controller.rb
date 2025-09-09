class BooksController < ApplicationController
  before_action :set_book, only: [:show, :edit, :update, :destroy, :refresh_from_google_books]

  def index
    @books = current_user.books.includes(:user).order(created_at: :desc)
  end

  def show
  end

  def new
    @book = current_user.books.build
  end

  def create
    @book = current_user.books.build(book_params)
    
    if @book.save
      redirect_to @book, notice: 'Book was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @book.update(book_params)
      # 読書状態が変更された場合の処理
      if params[:book][:reading_status].present?
        status_name = @book.reading_status.humanize
        redirect_to books_path, notice: "読書状態を「#{status_name}」に変更しました。"
      else
        redirect_to @book, notice: 'Book was successfully updated.'
      end
    else
      if params[:book][:reading_status].present?
        redirect_to books_path, alert: '読書状態の変更に失敗しました。'
      else
        render :edit
      end
    end
  end

  def destroy
    @book.destroy
    redirect_to books_url, notice: 'Book was successfully deleted.'
  end

  # Google Books API連携機能

  def search
    @query = params[:query] || params[:isbn]
    @search_results = []
    
    if @query.blank?
      return
    end

    # まずISBN検索を試す
    @search_results = GoogleBooksService.search_by_isbn(@query)
    
    # ISBNで見つからない場合はタイトル検索を試す
    if @search_results.blank?
      @search_results = GoogleBooksService.search_by_title(@query)
    end
    
    @search_results ||= []
  end

  def search_google_books
    query = params[:q]
    author = params[:author]
    
    if query.blank?
      render json: { error: 'Search query is required' }, status: :bad_request
      return
    end

    results = Book.search_google_books_by_title(query, author: author)
    render json: { books: results }
  end

  def refresh_from_google_books
    if @book.refresh_from_google_books!
      redirect_to @book, notice: 'Book information was successfully updated from Google Books!'
    else
      redirect_to @book, alert: 'Failed to update book information from Google Books'
    end
  end

  def new_from_google_books
    @book = current_user.books.build
    
    # Google Books情報を事前設定
    if params[:google_books_id].present?
      @book.google_books_id = params[:google_books_id]
      @book.title = params[:title]
      @book.author = params[:author]
      @book.publisher = params[:publisher]
      @book.published_date = params[:published_date]
      @book.description = params[:description]
      @book.isbn_10 = params[:isbn_10]
      @book.isbn_13 = params[:isbn_13]
      @book.image_url = params[:image_url]
    end
    
    render :new
  end

  def create_from_google_books
    book_data = {
      google_books_id: params[:google_books_id],
      title: params[:title],
      author: params[:author],
      publisher: params[:publisher],
      published_date: params[:published_date],
      description: params[:description],
      isbn_10: params[:isbn_10],
      isbn_13: params[:isbn_13],
      image_url: params[:image_url]
    }
    
    begin
      book = Book.create_from_google_books_data(user: current_user, data: book_data)
      redirect_to book, notice: 'Book was successfully added from Google Books!'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to books_path, alert: "Failed to create book: #{e.message}"
    end
  end


  private

  def set_book
    @book = current_user.books.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :purchase_reason, :purchase_date, 
                                 :author, :publisher, :published_date, 
                                 :description, :isbn_10, :isbn_13, :image_url, 
                                 :google_books_id, :reading_status)
  end
end