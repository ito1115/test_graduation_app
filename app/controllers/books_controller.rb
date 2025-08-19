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
      redirect_to @book, notice: 'Book was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @book.destroy
    redirect_to books_url, notice: 'Book was successfully deleted.'
  end

  # Google Books API連携機能
  def search_by_isbn
    isbn = params[:isbn]
    
    if isbn.blank?
      render json: { error: 'ISBN is required' }, status: :bad_request
      return
    end

    results = Book.search_google_books_by_isbn(isbn)
    
    if results.empty?
      render json: { error: 'No books found for this ISBN' }, status: :not_found
    else
      render json: { books: results }
    end
  end

  def create_from_isbn
    query = params[:isbn]
    
    if query.blank?
      redirect_to books_path, alert: 'Search query is required'
      return
    end

    # まずISBN検索を試す
    book = Book.create_from_isbn(user: current_user, isbn: query)
    
    # ISBNで見つからない場合はタイトル検索を試す
    if book.nil?
      results = GoogleBooksService.search_by_title(query)
      if results && !results.empty?
        # 常に検索結果ページを表示してユーザーに選択させる
        @search_results = results
        @query = query
        render :search_results
        return
      end
    end
    
    if book
      redirect_to book, notice: 'Book was successfully added from Google Books!'
    else
      redirect_to books_path, alert: "Could not find book with query '#{query}' or failed to create"
    end
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
    
    book = Book.create_from_google_books_data(user: current_user, data: book_data)
    
    if book
      redirect_to book, notice: 'Book was successfully added from Google Books!'
    else
      redirect_to books_path, alert: 'Failed to create book from Google Books data'
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
                                 :google_books_id)
  end
end