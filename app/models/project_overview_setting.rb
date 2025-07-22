class ProjectOverviewSetting < ActiveRecord::Base
    belongs_to :project
    
    validates :project_id, presence: true, uniqueness: true
    
    def self.for_project(project)
      find_or_create_by(project: project)
    end
    
    def dashboard_config
      super || {}
    end
  end