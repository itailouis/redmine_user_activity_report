require_dependency 'redmine_user_activity_report/daily_activity_helper'

# Add our helper to ApplicationController
Rails.application.config.to_prepare do
  ApplicationController.class_eval do
    before_action :check_and_record_daily_activity, if: :perform_daily_activity_check?
    
    private
    
    def perform_daily_activity_check?
      # Only perform the check for GET requests and not for API/JS/XML requests
      request.get? && 
      !request.xhr? && 
      request.format.html? &&
      User.current.logged? &&
      Setting.plugin_redmine_user_activity_report['enable_auto_daily_activity'] != '0'
    end
    
    def check_and_record_daily_activity
      if RedmineUserActivityReport::DailyActivityHelper.should_record_daily_activity?
        # Run in a separate thread to avoid blocking the request
        Thread.new do
          RedmineUserActivityReport::DailyActivityHelper.record_daily_activity
        end
      end
    end
  end
end
