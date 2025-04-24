# config/routes.rb
# Add routes to the plugin

 Rails.application.routes.draw do
   resources :user_activity_report, only: [:index, :show]
   resources :user_activity_histories, only: [:index, :show]
 end

