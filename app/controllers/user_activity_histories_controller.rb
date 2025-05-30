# app/controllers/user_activity_histories_controller.rb - FIXED VERSION
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
    if Setting.plugin_redmine_user_activity_report['restrict_access'] == '1' && !User.current.admin?
      # Get all projects the current user can manage
      managed_project_ids = Project.where(Project.allowed_to_condition(User.current, :manage_members)).pluck(:id)

      # Get users in those projects
      user_ids = Member.where(:project_id => managed_project_ids).pluck(:user_id).uniq

      @histories = @histories.where(:user_id => user_ids)
    end
  end

  def show
    # Check if current user can view this user's history
    unless can_view_user_history?(@user)
      render_403
      return
    end

    # Default to past 30 days if no date range is specified
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.today - 30.days
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today

    @histories = UserActivityHistory.date_range_for_user(@user.id, @start_date, @end_date)

    # Prepare trend chart data
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

    # Prepare project contribution radar chart data
    @project_radar_data = {
      labels: [],
      open_counts: [],
      closed_counts: [],
      total_counts: []
    }

    # Get the latest history record to use for the radar chart
    latest_history = @histories.order(activity_date: :desc).first

    # DEBUG: Log what we're getting
    Rails.logger.info "=== PROJECT RADAR DEBUG ==="
    Rails.logger.info "Latest history exists: #{latest_history.present?}"
    if latest_history
      Rails.logger.info "Projects summary raw: #{latest_history.read_attribute(:projects_summary)}"
      Rails.logger.info "Projects summary present: #{latest_history.projects_summary.present?}"
      Rails.logger.info "Projects summary class: #{latest_history.projects_summary.class}"
      Rails.logger.info "Projects summary content: #{latest_history.projects_summary.inspect}"
    end

    # Try multiple approaches to get project data
    projects_data = nil

    # Approach 1: Try to use stored projects_summary
    if latest_history && latest_history.projects_summary.present? && latest_history.projects_summary.is_a?(Hash)
      projects_data = latest_history.projects_summary
      Rails.logger.info "Using stored projects_summary"
    end

    # Approach 2: If no stored data, generate it live from current data
    if projects_data.blank?
      Rails.logger.info "No stored data, generating live project data"
      projects_data = generate_current_project_data(@user)
    end

    # Process the project data for the radar chart
    if projects_data.present? && projects_data.is_a?(Hash)
      Rails.logger.info "Processing project data: #{projects_data.keys.count} projects"

      # Convert to array for sorting, handle both string and symbol keys
      projects_array = projects_data.map do |project_id, data|
        # Handle both hash formats
        if data.is_a?(Hash)
          {
            id: project_id,
            name: data['name'] || data[:name],
            open_count: (data['open_count'] || data[:open_count] || 0).to_i,
            closed_count: (data['closed_count'] || data[:closed_count] || 0).to_i,
            total_count: (data['total_count'] || data[:total_count] || 0).to_i
          }
        else
          nil
        end
      end.compact

      # Sort projects by total issue count (descending) and take top 8 for readability
      top_projects = projects_array.sort_by { |p| -p[:total_count] }.take(8)

      Rails.logger.info "Top projects count: #{top_projects.count}"

      top_projects.each do |project|
        @project_radar_data[:labels] << project[:name]
        @project_radar_data[:open_counts] << project[:open_count]
        @project_radar_data[:closed_counts] << project[:closed_count]
        @project_radar_data[:total_counts] << project[:total_count]
      end
    end

    Rails.logger.info "Final radar data labels: #{@project_radar_data[:labels]}"
    Rails.logger.info "=== END PROJECT RADAR DEBUG ==="
  end

  private

  # Generate current project data if stored data is not available
  def generate_current_project_data(user)
    projects_data = {}

    Project.all.each do |project|
      # Check if user has any issues in this project
      project_open_count = Issue.where(
        assigned_to_id: user.id,
        project_id: project.id
      ).open.count

      project_closed_count = Issue.where(
        assigned_to_id: user.id,
        project_id: project.id,
        status_id: IssueStatus.where(is_closed: true).pluck(:id)
      ).count

      project_total = project_open_count + project_closed_count

      # Only include projects with issues
      if project_total > 0
        projects_data[project.id.to_s] = {
          'name' => project.name,
          'open_count' => project_open_count,
          'closed_count' => project_closed_count,
          'total_count' => project_total
        }
      end
    end

    Rails.logger.info "Generated live project data: #{projects_data.keys.count} projects"
    projects_data
  end

  def require_history_allowed
    # First check if history access is enabled in settings
    unless Setting.plugin_redmine_user_activity_report['allow_history_access'] == '1'
      render_403
      return false
    end

    # Then check user permissions
    unless User.current.admin? ||
           User.current.allowed_to_globally?(:manage_activity_history) ||
           (User.current.allowed_to_globally?(:view_own_activity_only) && action_name == 'show' && params[:id].to_i == User.current.id) ||
           (Setting.plugin_redmine_user_activity_report['allow_project_managers'] == '1' && is_manager_of_any_project?)
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
    if Setting.plugin_redmine_user_activity_report['allow_project_managers'] == '1'
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

# Also create this debug rake task to check what's in the database:
# lib/tasks/debug_user_activity.rake

