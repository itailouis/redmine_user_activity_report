# config/routes.rb
# Add routes to the plugin

Rails.application.routes.draw do
  resources :user_activity_report, only: [:index, :show]
  resources :user_activity_histories, only: [:index, :show]
  resources :project_activity, only: [:index]
  resources :projects_overview, only: [:index]
  get 'projects/:project_id/activity', to: 'project_activity#index', as: 'project_activity_report'
  get 'projects/:project_id/overview', to: 'projects_overview#index', as: 'project_overview'
  
  # Reports routes
  resources :reports, only: [:index] do
    collection do
      get :sla
      get :queue_wait
      get :oldest_issues
      get :roadmap
      get :daily_activity
      get :deficiencies
      get :burn_down
    end
  end
end
