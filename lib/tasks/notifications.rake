namespace :notifications do
  desc "Send weekly recommendation emails to eligible users"
  task send_weekly_recommendations: :environment do
    puts "Starting weekly recommendation email batch process..."
    
    # 推薦対象ユーザーを取得
    eligible_users = User.for_weekly_recommendation
    
    puts "Found #{eligible_users.count} eligible users for recommendation"
    
    sent_count = 0
    failed_count = 0
    
    eligible_users.find_each do |user|
      begin
        puts "Processing user: #{user.email}"
        
        # 推薦本を選択
        recommended_book = Book.select_recommendation_book(user)
        
        if recommended_book
          # メール送信
          TsundokuMailer.weekly_recommendation(user).deliver_now
          
          # 通知履歴を記録
          Notification.log_notification(
            user: user,
            type: 'recommendation',
            book: recommended_book
          )
          
          sent_count += 1
          puts "  → Sent recommendation for: #{recommended_book.title}"
        else
          puts "  → No suitable book found for recommendation"
        end
        
      rescue => e
        failed_count += 1
        puts "  → Failed to send email to #{user.email}: #{e.message}"
        Rails.logger.error "Weekly recommendation batch error for user #{user.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    
    puts "Batch process completed!"
    puts "Successfully sent: #{sent_count} emails"
    puts "Failed: #{failed_count} emails"
    
    # 結果をログに記録
    Rails.logger.info "Weekly recommendation batch completed - Sent: #{sent_count}, Failed: #{failed_count}"
  end
end