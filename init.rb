Redmine::Plugin.register :redmine_user_activity_report do

  name 'User Activity Report'
  author 'Itai Louis Zulu'
  description 'Shows a report on when users last logged in and how many issues they have in each project'
  version '0.1.0'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  # Add detailed permissions for this plugin
  project_module :redmine_user_activity_report do
    permission :view_user_activity_report, {
      :user_activity_report => [:index, :show],
      :user_activity_histories => [:index, :show]
    }
    permission :view_own_activity_only, {
      :user_activity_report => [:show],
      :user_activity_histories => [:show]
    }
    permission :manage_activity_history, {
      :user_activity_report => [:index, :show],
      :user_activity_histories => [:index, :show]
    }
  end

  # Add settings
  settings :default => {
    'restrict_access' => '1',
    'allow_project_managers' => '0',
    'allow_history_access' => '1',
    'history_retention_months' => '12'
  }, :partial => 'settings/redmine_user_activity_report_settings'

  # Add menu items based on settings and permissions
  menu :top_menu, :redmine_user_activity_report,
       { :controller => 'user_activity_report', :action => 'index' },
       :caption => 'User Activity Report',
       :if => Proc.new { |p| User.current.admin? || User.current.allowed_to_globally?(:view_user_activity_report) }

  menu :top_menu, :redmine_user_activity_report,
       { :controller => 'user_activity_histories', :action => 'index' },
       :caption => 'Activity History',
       :if => Proc.new { |p|
         (User.current.admin? || User.current.allowed_to_globally?(:manage_activity_history)) &&
         Setting.plugin_redmine_user_activity_report['allow_history_access'] == '1'
       }
end

 # Update the plugin initialization to include a cron job setup
 # Add this to the bottom of init.rb
 Rails.configuration.to_prepare do
   # Set up scheduled task if Rails Cron is available (usually in production)
   if Redmine::Plugin.installed?(:redmine_cron)
     begin
       # Use logger to debug
       Rails.logger.info "Attempting to register User Activity Report cron job"
     Redmine::Cron::CronJob.create(
       name: 'Record User Activity',
       schedule: '* * * * *', # Run at midnight every day
       command: 'rake redmine:plugins:user_activity_report:record_daily_activity'
     )
       Rails.logger.info "Successfully registered User Activity Report cron job"
     rescue => e
       # Log any errors
       Rails.logger.error "Failed to register User Activity Report cron job: #{e.message}"
     end
   end
 end