class UserActivityHistoriesController < ApplicationController
  layout 'admin'

  # Replace require_admin with permission check logic
  before_action :require_history_allowed
  before_action :find_user, :only => [:show]

  def index
    # Only admins and users with global permission can see all users
    unless User.current.admin? || User.current.allowed_to_globally?(:manage_activity_history)
      render_403
      return
    end

    @date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    @histories = UserActivityHistory.for_date(@date).includes(:user)

    # Filter to only show project members if setting is enabled
    if Setting.plugin_user_activity_report['restrict_access'] == '1' && !User.current.admin?
      # Get all projects the current user can manage
      managed_project_ids = Project.where(Project.allowed_to_condition(User.current, :manage_members)).pluck(:id)

      # Get users in those projects
      user_ids = Member.where(:project_id => managed_project_ids).pluck(:user_id).uniq

      @histories = @histories.where(:user_id => user_ids)
    end
  end

  def show
    # Check if current user can view this user's details
    unless can_view_user_history?(@user)
      render_403
      return
    end

    # Default to past 30 days if no date range is specified
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.today - 30.days
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today

    @histories = UserActivityHistory.date_range_for_user(@user.id, @start_date, @end_date)

    # Prepare chart data
    @chart_data = {
      labels: [],
      open: [],
      closed: []
    }

    @histories.each do |history|
      @chart_data[:labels] << history.activity_date.strftime("%Y-%m-%d")
      @chart_data[:open] << history.open_issues_count
      @chart_data[:closed] << history.closed_issues_count
    end
  end

  private

  def require_history_allowed
    # First check if history access is enabled in settings
    unless Setting.plugin_user_activity_report['allow_history_access'] == '1'
      render_403
      return false
    end

    # Then check user permissions
    unless User.current.admin? ||
           User.current.allowed_to_globally?(:manage_activity_history) ||
           (User.current.allowed_to_globally?(:view_own_activity_only) && action_name == 'show' && params[:id].to_i == User.current.id) ||
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

  def can_view_user_history?(user)
    # Admins can view all users
    return true if User.current.admin?

    # Users can always view themselves if they have own_activity permission
    return true if User.current == user && User.current.allowed_to_globally?(:view_own_activity_only)

    # Users with global permission can view all users
    return true if User.current.allowed_to_globally?(:manage_activity_history)

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