require 'fileutils'

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
      :user_activity_histories => [:index, :show],
      :project_activity => [:index],
      :projects_overview => [:index]
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

  # Add permissions to admin role
  #Role.find_by_name('Administrator').add_permission!(:view_user_activity_report, :manage_activity_history, :view_own_activity_only)

  

  # Add project overview menu items
  menu :project_menu, :overview,
       { :controller => 'projects_overview', :action => 'index' },
       :caption => 'Overview',
       :if => Proc.new { |p| User.current.allowed_to?(:view_user_activity_report, p) || User.current.admin? }

  menu :project_menu, :activity_report,
       { :controller => 'project_activity', :action => 'index' },
       :caption => 'Activity Report',
       :if => Proc.new { |p| User.current.allowed_to?(:view_user_activity_report, p) }

  # Add top menu items
  menu :top_menu, :projects_overview,
       { :controller => 'projects_overview', :action => 'index' },
       :caption => 'Projects Overview',
       :if => Proc.new { |p| User.current.allowed_to_globally?(:view_user_activity_report) }

  menu :top_menu, :reports,
       { :controller => 'reports', :action => 'index' },
       :caption => 'Activity Reports',
       :if => Proc.new { |p| User.current.admin? }

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
       :if => Proc.new { |p| User.current.admin? || User.current.allowed_to_globally?(:view_user_activity_report) }
       #:if => Proc.new { |p|
       #  (User.current.admin? || User.current.allowed_to_globally?(:manage_activity_history)) &&
       #  Setting.plugin_redmine_user_activity_report['allow_history_access'] == '1'
      # }
end

 # Update the plugin initialization to include a cron job setup and register assets
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
  
   # Register plugin assets
   begin
     # Register stylesheets
     Rails.logger.info "Registering User Activity Report assets"
    
     # Create the plugin assets directory if it doesn't exist
     plugin_assets_path = File.join(Redmine::Plugin.public_directory, 'redmine_user_activity_report')
     FileUtils.mkdir_p(plugin_assets_path) unless File.directory?(plugin_assets_path)
    
     # Copy stylesheets
     stylesheets_dir = File.join(plugin_assets_path, 'stylesheets')
     FileUtils.mkdir_p(stylesheets_dir) unless File.directory?(stylesheets_dir)
    
     # Copy javascripts
     javascripts_dir = File.join(plugin_assets_path, 'javascripts')
     FileUtils.mkdir_p(javascripts_dir) unless File.directory?(javascripts_dir)
    
     # Copy CSS files
     plugin_stylesheets_dir = File.join(File.dirname(__FILE__), 'public', 'stylesheets')
     if File.directory?(plugin_stylesheets_dir)
       Dir.glob(File.join(plugin_stylesheets_dir, '*.css')).each do |file|
         FileUtils.cp(file, stylesheets_dir)
       end
     end
    
     # Copy JavaScript files
     plugin_javascripts_dir = File.join(File.dirname(__FILE__), 'public', 'javascripts')
     if File.directory?(plugin_javascripts_dir)
       Dir.glob(File.join(plugin_javascripts_dir, '*.js')).each do |file|
         FileUtils.cp(file, javascripts_dir)
       end
     end
    
     Rails.logger.info "Successfully registered User Activity Report assets"
   rescue => e
     # Log any errors
     Rails.logger.error "Failed to register User Activity Report assets: #{e.message}"
   end
 end
