class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :book
  
  validates :notification_type, presence: true, inclusion: { 
    in: %w[recommendation reminder weekly_digest monthly_summary],
    message: "%{value} is not a valid notification type" 
  }
  validates :sent_at, presence: true
  
  scope :sent, -> { where.not(sent_at: nil) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :recent, -> { order(sent_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :with_book, -> { where.not(book_id: nil) }
  scope :sent_today, -> { where(sent_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :sent_this_week, -> { where(sent_at: 1.week.ago..Time.current) }
  
  def recommendation?
    notification_type == 'recommendation'
  end
  
  def reminder?
    notification_type == 'reminder'
  end
  
  def self.log_notification(user:, type:, book: nil)
    create!(
      user: user,
      book: book,
      notification_type: type,
      sent_at: Time.current
    )
  end
  
  def self.recent_notifications_count(user, days = 7)
    for_user(user).where(sent_at: days.days.ago..Time.current).count
  end
end