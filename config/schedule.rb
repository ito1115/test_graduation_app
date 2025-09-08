# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Rails環境とログの設定
set :environment, 'production'
set :output, "#{path}/log/cron.log"

# 毎週日曜日の午前9時に週次推薦メールを送信
every :sunday, at: '9:00 am' do
  rake 'notifications:send_weekly_recommendations'
end