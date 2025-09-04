class TsundokuMailer < ApplicationMailer
  def weekly_recommendation(user)
    @user = user
    @recommended_book = Book.select_recommendation_book(user)
    @tsundoku_count = user.books.tsundoku.count
    
    # 推薦する本がない場合はメール送信をスキップ
    return if @recommended_book.nil?
    
    mail(
      to: @user.email,
      subject: "📚 今週の積読本おすすめ - #{@recommended_book.title} はいかがですか？"
    )
  end
end