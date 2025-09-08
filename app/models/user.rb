class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :books, dependent: :destroy
  has_many :notifications, dependent: :destroy
  
  # 推薦対象ユーザーのスコープ
  scope :eligible_for_recommendation, -> {
    joins(:books)
      .where(books: { reading_status: Book.reading_statuses[:tsundoku] })
      .distinct
  }
  
  # 最近通知を受けていないユーザー
  scope :not_recently_notified, ->(days = 7) {
    left_joins(:notifications)
      .where(
        notifications: { id: nil }
      ).or(
        where.not(
          id: recent_notification_user_ids(days)
        )
      )
  }
  
  # 推薦メール送信対象ユーザー
  scope :for_weekly_recommendation, -> {
    eligible_for_recommendation
      .not_recently_notified
  }
  
  class << self
    # 最近通知を受けたユーザーIDを取得
    def recent_notification_user_ids(days = 7)
      Notification.where(sent_at: days.days.ago..Time.current)
                  .pluck(:user_id)
                  .uniq
    end
  end
  
  # ユーザーが推薦対象かどうか
  def eligible_for_recommendation?
    books.tsundoku.exists?
  end
  
  # 最近通知を受けたかどうか
  def recently_notified?(days = 7)
    notifications.where(sent_at: days.days.ago..Time.current).exists?
  end
end