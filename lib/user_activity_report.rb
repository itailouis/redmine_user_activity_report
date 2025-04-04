module UserActivityReport
  class << self
    def setup
      # Load controllers
      require_dependency 'user_activity_report/hooks'
    end
  end
end

Rails.configuration.to_prepare do
  UserActivityReport.setup
end