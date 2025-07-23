# config/routes.rb
# Add routes to the plugin

Rails.application.routes.draw do
  resources :user_activity_report, only: [:index, :show]
  resources :user_activity_histories, only: [:index, :show]
  resources :project_activity, only: [:index]
  resources :projects_overview, only: [:index]
  get 'projects/:project_id/activity', to: 'project_activity#index', as: 'project_activity_report'
  get 'projects/:project_id/overview', to: 'projects_overview#index', as: 'project_overview'
  
  # Reports routes - simplified structure
  resources :reports, only: [] do
    collection do
      get :index
      get :sla
      get :queue_wait
      get :oldest_issues
      get :roadmap
      get :daily_activity
      get :deficiencies
      get :burn_down
      get :project_specific
      get :progress
      get :export_project_report
      get :export_progress_report
      get :issues_by_project_and_assignee
      get :export_issues_by_project_and_assignee, format: :csv
    end
  end
  
  # Likes routes
  scope :user_activity_report do
    resources :likes, only: [] do
      collection do
        get 'count'
        post 'toggle'
      end
    end
  end
end
