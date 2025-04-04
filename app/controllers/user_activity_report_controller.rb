class UserActivityReportController < ApplicationController
  layout 'admin'

  # Replace require_admin with permission check logic
  before_action :require_user_allowed
  before_action :find_user, :only => [:show]

  def index
    # Only admins and users with global permission can see all users
    unless User.current.admin? || User.current.allowed_to_globally?(:view_user_activity_report)
      # Redirect users with only own access to their own page
      if User.current.allowed_to_globally?(:view_own_activity_only)
        redirect_to user_activity_report_path(User.current)
        return
      end
      # Otherwise deny access
      render_403
      return
    end

    @users = User.active.sorted

    # Filter to only show project members if setting is enabled
    if Setting.plugin_user_activity_report['restrict_access'] == '1' && !User.current.admin?
      # Get all projects the current user can manage
      managed_project_ids = Project.where(Project.allowed_to_condition(User.current, :manage_members)).pluck(:id)

      # Get users in those projects
      user_ids = Member.where(:project_id => managed_project_ids).pluck(:user_id).uniq

      @users = @users.where(:id => user_ids)
    end

    # Initialize chart data
    @user_chart_data = {
      :labels => [],
      :open => [],
      :closed => []
    }

    # Only process chart data if there are users
    if @users.present?
      @users.each do |user|
        # Skip users with no issues
        open_count = Issue.visible.where(:assigned_to_id => user.id).open.count
        closed_count = Issue.visible.where(:status_id => IssueStatus.where(:is_closed => true).pluck(:id), :assigned_to_id => user.id).count

        # Only add to chart if user has issues
        if open_count > 0 || closed_count > 0
          @user_chart_data[:labels] << user.name
          @user_chart_data[:open] << open_count
          @user_chart_data[:closed] << closed_count
        end
      end
    end
  end

  def show
    # Check if current user can view this user's details
    unless can_view_user?(@user)
      render_403
      return
    end

    @projects = Project.all
    @issues_by_project = {}
    @chart_data = { :labels => [], :open => [], :closed => [] }

    @projects.each do |project|
      next unless User.current.allowed_to?(:view_issues, project)

      total_count = Issue.visible.where(:assigned_to_id => @user.id, :project_id => project.id).count
      open_count = Issue.visible.where(:assigned_to_id => @user.id, :project_id => project.id).open.count
      closed_count = Issue.visible.where(:assigned_to_id => @user.id, :project_id => project.id).where(:status_id => IssueStatus.where(:is_closed => true).pluck(:id)).count

      # Skip projects with no issues for the chart
      if total_count > 0
        @chart_data[:labels] << project.name
        @chart_data[:open] << open_count
        @chart_data[:closed] << closed_count
      end

      @issues_by_project[project.id] = {
        :name => project.name,
        :count => total_count,
        :open_count => open_count,
        :closed_count => closed_count
      }
    end

    # Get data for a pie chart showing issue priority distribution
    @priority_data = { :labels => [], :data => [], :colors => [] }

    # Get all issue priorities with issues assigned to this user
    priorities = IssuePriority.all
    priorities.each do |priority|
      count = Issue.visible.where(:assigned_to_id => @user.id).open.where(:priority_id => priority.id).count
      if count > 0
        @priority_data[:labels] << priority.name
        @priority_data[:data] << count

        # Generate a color based on priority position
        hue = 210 - (180 * (priority.position.to_f / priorities.length))
        @priority_data[:colors] << "hsl(#{hue}, 70%, 50%)"
      end
    end
  end

  private

  def require_user_allowed
    # Check if we're in admin mode (for backward compatibility)
    if params[:admin] && User.current.admin?
      return true
    end

    # Check if user has appropriate permission
    unless User.current.admin? ||
           User.current.allowed_to_globally?(:view_user_activity_report) ||
           User.current.allowed_to_globally?(:view_own_activity_only) ||
           (Setting.plugin_user_activity_report['allow_project_managers'] == '1' && is_manager_of_any_project?)
      render_403
      return false
    end
    true
  end

  def find_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def can_view_user?(user)
    # Admins can view all users
    return true if User.current.admin?

    # Users can always view themselves
    return true if User.current == user

    # Users with global permission can view all users
    return true if User.current.allowed_to_globally?(:view_user_activity_report)

    # Project managers can view their project members if enabled
    if Setting.plugin_user_activity_report['allow_project_managers'] == '1'
      return is_manager_of_user?(user)
    end

    false
  end

  def is_manager_of_any_project?
    Project.where(Project.allowed_to_condition(User.current, :manage_members)).any?
  end

  def is_manager_of_user?(user)
    # Get projects where current user is manager
    managed_project_ids = Project.where(Project.allowed_to_condition(User.current, :manage_members)).pluck(:id)

    # Check if target user is a member of any of these projects
    Member.where(:project_id => managed_project_ids, :user_id => user.id).any?
  end
end