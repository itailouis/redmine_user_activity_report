class ProjectsOverviewController < ApplicationController
  before_action :find_project, except: [:index]
  before_action :authorize, except: [:index]
  before_action :require_login, only: [:index]

  def index
    if params[:project_id].present?
      begin
        @project = Project.find(params[:project_id])
        authorize
        @overview_data = calculate_overview_data
        @chart_data = prepare_chart_data
        @recent_activities = get_recent_activities
        @team_stats = calculate_team_statistics
      rescue ActiveRecord::RecordNotFound
        # Handle the case when the project doesn't exist
        flash[:error] = l(:error_project_not_found)
        redirect_to projects_path
        return
      end
    else
      # Handle the case when no project_id is provided
      @projects = Project.visible.order(:name)
      render 'index_all_projects'
    end
  end

  def show
    # Additional detailed view if needed
    redirect_to action: :index
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def calculate_overview_data
    # Return empty data if project is nil
    return empty_overview_data unless @project

    {
      total_issues: @project.issues.count,
      open_issues: @project.issues.open.count,
      closed_issues: @project.issues.count - @project.issues.open.count,
      completion_rate: calculate_completion_rate,
      total_time_entries: @project.time_entries.sum(:hours),
      project_health: calculate_project_health,
      milestone_progress: calculate_milestone_progress,
      priority_breakdown: calculate_priority_breakdown,
      status_breakdown: calculate_status_breakdown,
      tracker_breakdown: calculate_tracker_breakdown
    }
  end
  
  def empty_overview_data
    {
      total_issues: 0,
      open_issues: 0,
      closed_issues: 0,
      completion_rate: 0,
      total_time_entries: 0,
      project_health: 'unknown',
      milestone_progress: [],
      priority_breakdown: [],
      status_breakdown: [],
      tracker_breakdown: []
    }
  end

  def calculate_completion_rate
    return 0 unless @project
    
    total = @project.issues.count
    return 0 if total.zero?
    
    closed = @project.issues.count - @project.issues.open.count
    ((closed.to_f / total) * 100).round(2)
  end

  def calculate_project_health
    return 'unknown' unless @project
    
    open_issues = @project.issues.open.count
    overdue_issues = @project.issues.open.where('due_date < ?', Date.current).count
    
    return 'excellent' if open_issues.zero?
    
    overdue_percentage = overdue_issues.to_f / open_issues * 100
    
    case overdue_percentage
    when 0..10
      'good'
    when 11..25
      'fair'
    when 26..50
      'poor'
    else
      'critical'
    end
  end

  def calculate_milestone_progress
    return [] unless @project
    
    versions = @project.versions.open
    return [] if versions.empty?

    versions.map do |version|
      total_issues = version.fixed_issues.count
      closed_issues = version.fixed_issues.count - version.fixed_issues.open.count
      progress = total_issues.zero? ? 0 : (closed_issues.to_f / total_issues * 100).round(2)
      
      {
        name: version.name,
        due_date: version.due_date,
        progress: progress,
        total_issues: total_issues,
        closed_issues: closed_issues,
        status: version_status(version, progress)
      }
    end
  end

  def version_status(version, progress)
    return 'completed' if progress == 100
    return 'on-track' if version.due_date.nil? || version.due_date > Date.current
    
    days_remaining = (version.due_date - Date.current).to_i
    return 'overdue' if days_remaining < 0
    return 'at-risk' if days_remaining <= 7 && progress < 80
    
    'on-track'
  end

  def calculate_priority_breakdown
    return [] unless @project
    
    @project.issues.group(:priority_id).count.map do |priority_id, count|
      priority_name = IssuePriority.find(priority_id).name rescue 'Unknown'
      { name: priority_name, count: count }
    end
  end

  def calculate_status_breakdown
    return [] unless @project
    
    @project.issues.joins(:status).group('issue_statuses.name').count.map do |status, count|
      { name: status, count: count }
    end
  end

  def calculate_tracker_breakdown
    return [] unless @project
    
    @project.issues.joins(:tracker).group('trackers.name').count.map do |tracker, count|
      { name: tracker, count: count }
    end
  end

  def prepare_chart_data
    return empty_chart_data unless @project
    
    {
      issues_over_time: issues_over_time_data,
      burndown_data: calculate_burndown_data,
      workload_distribution: calculate_workload_distribution,
      issue_resolution_time: calculate_resolution_time_data
    }
  end
  
  def empty_chart_data
    {
      issues_over_time: [],
      burndown_data: [],
      workload_distribution: [],
      issue_resolution_time: { average: 0, median: 0, min: 0, max: 0 }
    }
  end

  def issues_over_time_data
    return [] unless @project
    
    start_date = @project.created_on.beginning_of_month
    end_date = Date.current.end_of_month
    
    data = []
    current_date = start_date
    
    while current_date <= end_date
      created_count = @project.issues.where(created_on: current_date.beginning_of_month..current_date.end_of_month).count
      # Count issues that were closed during this month
      # First get issues that have a closed_on date in this month
      issues_with_closed_date = @project.issues.where(closed_on: current_date.beginning_of_month..current_date.end_of_month)
      # Then get issues that were updated in this month and are not open (i.e., closed)
      issues_updated_and_closed = @project.issues.where(updated_on: current_date.beginning_of_month..current_date.end_of_month)
                                         .where.not(id: @project.issues.open)
      # Combine both sets and count unique issues
      closed_count = (issues_with_closed_date + issues_updated_and_closed).uniq.count
      
      data << {
        date: current_date.strftime('%Y-%m'),
        created: created_count,
        closed: closed_count
      }
      
      current_date = current_date.next_month
    end
    
    data
  end

  def calculate_burndown_data
    return [] unless @project
    return [] unless @project.versions.open.any?
    
    current_version = @project.versions.open.first
    return [] unless current_version.due_date
    
    start_date = current_version.created_on.to_date
    end_date = current_version.due_date
    total_issues = current_version.fixed_issues.count
    
    data = []
    current_date = start_date
    
    while current_date <= end_date
      remaining_issues = current_version.fixed_issues.open.where('created_on <= ?', current_date.end_of_day).count
      ideal_remaining = calculate_ideal_burndown(current_date, start_date, end_date, total_issues)
      
      data << {
        date: current_date.strftime('%Y-%m-%d'),
        actual: remaining_issues,
        ideal: ideal_remaining
      }
      
      current_date = current_date.next_day
      break if current_date > Date.current
    end
    
    data
  end

  def calculate_ideal_burndown(current_date, start_date, end_date, total_issues)
    total_days = (end_date - start_date).to_i
    elapsed_days = (current_date - start_date).to_i
    
    return total_issues if elapsed_days <= 0
    return 0 if elapsed_days >= total_days
    
    remaining_ratio = (total_days - elapsed_days).to_f / total_days
    (total_issues * remaining_ratio).round
  end

  def calculate_workload_distribution
    return [] unless @project
    
    @project.assignable_users.map do |user|
      open_issues = @project.issues.open.where(assigned_to: user).count
      total_hours = @project.time_entries.where(user: user).sum(:hours)
      
      {
        name: user.name,
        open_issues: open_issues,
        total_hours: total_hours
      }
    end.select { |data| data[:open_issues] > 0 || data[:total_hours] > 0 }
  end

  def calculate_resolution_time_data
    return { average: 0, median: 0, min: 0, max: 0 } unless @project
    
    # Get all issues that are not open (i.e., closed) and have a closed_on date
    closed_issues = @project.issues.where.not(id: @project.issues.open).where.not(closed_on: nil)
    return { average: 0, median: 0, min: 0, max: 0 } if closed_issues.empty?
    
    resolution_times = closed_issues.map do |issue|
      (issue.closed_on.to_date - issue.created_on.to_date).to_i
    end
    
    {
      average: resolution_times.sum.to_f / resolution_times.size,
      median: resolution_times.sort[resolution_times.size / 2],
      min: resolution_times.min,
      max: resolution_times.max
    }
  end

  def get_recent_activities
    return [] unless @project
    
    # Get issue IDs for this project
    issue_ids = @project.issues.pluck(:id)
    return [] if issue_ids.empty?
    
    # Query journals for these issues
    Journal.where(journalized_id: issue_ids, journalized_type: 'Issue')
           .joins(:user)
           .includes(:journalized, :user)
           .order(created_on: :desc)
           .limit(10)
           .map do |journal|
      {
        user: journal.user.name,
        action: journal_action_description(journal),
        date: journal.created_on,
        issue: journal.journalized
      }
    rescue => e
      Rails.logger.error "Error processing journal: #{e.message}"
      nil
    end.compact
  end

  def journal_action_description(journal)
    case journal.journalized_type
    when 'Issue'
      if journal.details.any?
        "Updated issue ##{journal.journalized.id}"
      else
        "Added note to issue ##{journal.journalized.id}"
      end
    else
      "Updated #{journal.journalized_type.downcase}"
    end
  end

  def calculate_team_statistics
    return empty_team_statistics unless @project
    
    team_members = @project.assignable_users
    
    {
      total_members: team_members.count,
      active_members: calculate_active_members(team_members),
      top_contributors: calculate_top_contributors(team_members),
      workload_balance: calculate_workload_balance(team_members)
    }
  end
  
  def empty_team_statistics
    {
      total_members: 0,
      active_members: 0,
      top_contributors: [],
      workload_balance: 'unknown'
    }
  end

  def calculate_active_members(team_members)
    return 0 unless @project
    
    team_members.select do |user|
      @project.time_entries.where(user: user, spent_on: 30.days.ago..Date.current).exists? ||
      @project.issues.where(assigned_to: user, updated_on: 30.days.ago..Date.current).exists?
    end.count
  end

  def calculate_top_contributors(team_members)
    return [] unless @project
    
    team_members.map do |user|
      issues_created = @project.issues.where(author: user).count
      issues_resolved = @project.issues.where.not(id: @project.issues.open).where(assigned_to: user).count
      time_logged = @project.time_entries.where(user: user).sum(:hours)
      
      score = issues_created * 1 + issues_resolved * 2 + time_logged * 0.1
      
      {
        user: user.name,
        score: score.round(2),
        issues_created: issues_created,
        issues_resolved: issues_resolved,
        time_logged: time_logged
      }
    end.sort_by { |contributor| -contributor[:score] }.first(5)
  end

  def calculate_workload_balance(team_members = nil)
    return 'unknown' unless @project
    
    # If team_members is not provided, get it from the project
    team_members ||= @project.assignable_users
    return 'balanced' if team_members.count <= 1
    
    workloads = team_members.map do |user|
      @project.issues.open.where(assigned_to: user).count
    end
    
    return 'balanced' if workloads.empty? || workloads.all?(&:zero?)
    
    avg_workload = workloads.sum.to_f / workloads.size
    max_deviation = workloads.map { |w| (w - avg_workload).abs }.max
    
    case max_deviation / avg_workload
    when 0..0.2
      'well-balanced'
    when 0.21..0.5
      'moderately-balanced'
    else
      'unbalanced'
    end
  end
end
