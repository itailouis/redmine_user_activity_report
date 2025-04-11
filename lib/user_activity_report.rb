module UserActivityReport
  class << self
    def setup
      # Load controllers
      require_dependency 'redmine_user_activity_report/hooks'
    end
  end
end

Rails.configuration.to_prepare do
  UserActivityReport.setup
end