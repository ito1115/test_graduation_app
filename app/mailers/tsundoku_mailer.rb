class TsundokuMailer < ApplicationMailer
  def weekly_recommendation(user)
    @user = user
    @recommended_book = user.books.tsundoku.order('RANDOM()').first
    @tsundoku_count = user.books.tsundoku.count
    
    mail(
      to: @user.email,
      subject: "📚 今週の積読本おすすめ - #{@recommended_book&.title || '積読本'} はいかがですか？"
    )
  end
end