# config/routes.rb
# Add routes to the plugin

 Rails.application.routes.draw do
   resources :user_activity_report, only: [:index, :show]
   resources :user_activity_histories, only: [:index, :show]
 end

 # Update the plugin initialization to include a cron job setup
 # Add this to the bottom of init.rb
 Rails.configuration.to_prepare do
   # Set up scheduled task if Rails Cron is available (usually in production)
   if Redmine::Plugin.installed?(:redmine_cron) && Rails.env.production?
     Redmine::Cron::CronJob.create(
       name: 'Record User Activity',
       schedule: '0 0 * * *', # Run at midnight every day
       command: 'rake redmine:plugins:user_activity_report:record_daily_activity'
     )
   end
 end