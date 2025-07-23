module RedmineUserActivityReport
  module DailyActivityHelper
    def self.should_record_daily_activity?
      last_run = Setting.plugin_redmine_user_activity_report['last_daily_activity_run']
      last_run_date = last_run ? Date.parse(last_run) : nil
      
      # If we've never run before or if it's a new day since last run
      last_run_date.nil? || last_run_date < Date.today
    end
    
    def self.record_daily_activity
      # Run the rake task in a separate process to avoid blocking the request
      command = if Rails.env.production?
        "cd #{Rails.root} && RAILS_ENV=production bundle exec rake redmine:plugins:user_activity_report:record_daily_activity"
      else
        "cd #{Rails.root} && bundle exec rake redmine:plugins:user_activity_report:record_daily_activity"
      end
      
      # Run command in background
      pid = Process.fork do
        exec(command)
      end
      Process.detach(pid)
      
      # Update the last run time
      settings = Setting.plugin_redmine_user_activity_report
      settings['last_daily_activity_run'] = Date.today.to_s
      Setting.plugin_redmine_user_activity_report = settings
    end
  end
end
