class ReportsController < ApplicationController
  before_action :require_login
  before_action :authorize_global
  before_action :load_projects, only: [:project_specific, :progress]

  def index
    # Set date range (default to last 30 days)
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    # Project statistics
    @project_stats = {
      total_projects: Project.visible.count,
      active_projects: Project.visible.active.count,
      public_projects: Project.visible.where(is_public: true).count,
      private_projects: Project.visible.where(is_public: false).count,
      projects_by_status: Project.visible.group(:status).count
    }
    
    # Issue statistics
    issues = Issue.visible.where('issues.created_on BETWEEN ? AND ?', @start_date, @end_date)
    
    # Get issues by author (using the correct association name)
    issues_by_author = User.joins("INNER JOIN issues ON issues.author_id = users.id")
                          .where("issues.created_on BETWEEN ? AND ?", @start_date, @end_date)
                          .group('users.id', 'users.firstname', 'users.lastname')
                          .order('count(issues.id) DESC')
                          .limit(10)
                          .count('issues.id')
    
    # Get issues by assignee
    issues_by_assignee = User.joins("INNER JOIN issues ON issues.assigned_to_id = users.id")
                            .where("issues.created_on BETWEEN ? AND ?", @start_date, @end_date)
                            .group('users.id', 'users.firstname', 'users.lastname')
                            .order('count(issues.id) DESC')
                            .limit(10)
                            .count('issues.id')
    
    @issue_stats = {
      total_issues: issues.count,
      open_issues: Issue.visible.open.count,
      closed_issues: Issue.visible.where(status: IssueStatus.where(is_closed: true)).count,
      issues_by_status: Issue.visible.group(:status).count,
      issues_by_priority: Issue.visible.group(:priority).count,
      issues_by_tracker: Issue.visible.group(:tracker).count,
      issues_by_author: issues_by_author,
      issues_by_assignee: issues_by_assignee
    }
    
    # User statistics
    @user_stats = {
      total_users: User.active.count,
      active_users: User.active.where('last_login_on > ?', 1.month.ago).count,
      users_by_role: Member.joins(:roles).group('roles.name').count,
      users_by_status: User.group(:status).count
    }
    
    # Prepare data for charts
    prepare_chart_data
    
    respond_to do |format|
      format.html
      format.json { render json: { project_stats: @project_stats, issue_stats: @issue_stats, user_stats: @user_stats, chart_data: @chart_data } }
    end
  end
  
  def dashboard
    # Alias for index action to maintain backward compatibility
    index
    render :index
  end

  def sla
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate SLA statistics
    @sla_stats = {}
    IssueStatus.all.each do |status|
      issues = Issue.where(status_id: status.id,
                         created_on: @start_date..@end_date)
      @sla_stats[status.id] = {
        name: status.name,
        count: issues.count,
        avg_response_time: calculate_avg_response_time(issues),
        avg_resolution_time: calculate_avg_resolution_time(issues),
        sla_compliance: calculate_sla_compliance(issues)
      }
    end
    
    # Add overall statistics
    all_issues = Issue.where(created_on: @start_date..@end_date)
    @sla_stats['overall'] = {
      name: 'Overall',
      count: all_issues.count,
      avg_response_time: calculate_avg_response_time(all_issues),
      avg_resolution_time: calculate_avg_resolution_time(all_issues),
      sla_compliance: calculate_sla_compliance(all_issues)
    }
    
    # Prepare data for time in status chart
    @time_in_status = calculate_time_in_status(all_issues)
  end

  def queue_wait
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate queue wait time statistics
    @queue_stats = (0..(@end_date - @start_date).to_i).map do |i|
      date = @start_date + i.days
      avg_wait = Issue.where(created_on: date.beginning_of_day..date.end_of_day)
                      .where(status_id: IssueStatus.open_ids)
                      .average(:created_on)
      avg_wait ||= 0
      [date.strftime('%Y-%m-%d'), avg_wait.round(1)]
    end.to_h
  end

  def oldest_issues
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Get oldest issues per status
    @oldest_issues = IssueStatus.all.map do |status|
      issue = Issue.where(status_id: status.id,
                         created_on: @start_date..@end_date)
                   .order(created_on: :asc)
                   .first
      {
        status: status,
        issue: issue
      } if issue
    end.compact
  end

  def roadmap
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate roadmap statistics
    @roadmap_stats = IssueStatus.all.map do |status|
      issues = Issue.where(status_id: status.id,
                         created_on: @start_date..@end_date)
      {
        status: status,
        count: issues.count,
        avg_resolution_time: calculate_avg_resolution_time(issues)
      }
    end
  end

  def daily_activity
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate daily activity statistics
    @activity_stats = (0..(@end_date - @start_date).to_i).map do |i|
      date = @start_date + i.days
      issues = Issue.where(created_on: date.beginning_of_day..date.end_of_day)
      {
        date: date,
        new_issues: issues.count,
        closed_issues: issues.where(status_id: IssueStatus.closed_ids).count
      }
    end
  end

  def deficiencies
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate deficiencies statistics
    @deficiencies_stats = IssueStatus.all.map do |status|
      issues = Issue.where(status_id: status.id,
                         created_on: @start_date..@end_date)
      {
        status: status,
        count: issues.count,
        avg_resolution_time: calculate_avg_resolution_time(issues)
      }
    end
  end

  def burn_down
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    # Calculate burn down statistics
    @burn_down_data = (0..(@end_date - @start_date).to_i).map do |i|
      date = @start_date + i.days
      remaining = Issue.where(created_on: @start_date..date,
                             status_id: IssueStatus.open_ids)
                       .count
      [date.strftime('%Y-%m-%d'), remaining]
    end.to_h
  end

  private

  def calculate_avg_response_time(issues)
    return 0 if issues.empty?
    
    # Calculate average time to first response
    response_times = []
    
    issues.each do |issue|
      begin
        # Find the first journal entry (comment/update) after issue creation
        first_response = Journal.where(journalized_id: issue.id, journalized_type: 'Issue')
                               .where('created_on > ?', issue.created_on)
                               .order(created_on: :asc)
                               .first
                               
        if first_response
          # Calculate time difference in days (ensure non-negative)
          response_time = [(first_response.created_on.to_date - issue.created_on.to_date).to_i, 0].max
          response_times << response_time
        end
      rescue => e
        # Log error and continue with next issue
        Rails.logger.error "Error calculating response time for issue ##{issue.id}: #{e.message}"
        next
      end
    end
    
    return 0 if response_times.empty?
    (response_times.sum.to_f / response_times.size).round(1)
  end
  
  def calculate_avg_resolution_time(issues)
    return 0 if issues.empty?
    
    begin
      # Calculate average time to resolution for closed issues
      closed_issues = issues.where(status_id: IssueStatus.closed_ids)
      return 0 if closed_issues.empty?
      
      resolution_times = []
      
      closed_issues.each do |issue|
        begin
          if issue.closed_on
            # Calculate time difference in days (ensure non-negative)
            resolution_time = [(issue.closed_on.to_date - issue.created_on.to_date).to_i, 0].max
            resolution_times << resolution_time
          end
        rescue => e
          # Log error and continue with next issue
          Rails.logger.error "Error calculating resolution time for issue ##{issue.id}: #{e.message}"
          next
        end
      end
      
      return 0 if resolution_times.empty?
      (resolution_times.sum.to_f / resolution_times.size).round(1)
    rescue => e
      # Log error and return 0
      Rails.logger.error "Error in calculate_avg_resolution_time: #{e.message}"
      return 0
    end
  end
  
  def calculate_sla_compliance(issues)
    return 0 if issues.empty?
    
    begin
      # Define SLA targets based on priority
      sla_targets = {
        'Immediate' => 1,  # 1 day
        'Urgent' => 3,     # 3 days
        'High' => 5,       # 5 days
        'Normal' => 10,    # 10 days
        'Low' => 15        # 15 days
      }
      
      # Default SLA target if priority not found
      default_sla = 10
      
      # Count issues that meet their SLA target
      compliant_count = 0
      total_count = 0
      
      closed_issues = issues.where(status_id: IssueStatus.closed_ids)
      return 0 if closed_issues.empty?
      
      closed_issues.each do |issue|
        begin
          if issue.closed_on
            total_count += 1
            
            # Get SLA target based on priority
            priority_name = begin
              # Access priority through priority_id instead of directly
              priority_id = issue.read_attribute(:priority_id)
              if priority_id
                # Map priority_id to a name based on our SLA targets
                case priority_id
                when 1 then 'Low'
                when 2 then 'Normal'
                when 3 then 'High'
                when 4 then 'Urgent'
                when 5 then 'Immediate'
                else 'Normal'
                end
              else
                'Normal'
              end
            rescue => e
              Rails.logger.error "Error getting priority for issue ##{issue.id}: #{e.message}"
              'Normal'
            end
            
            target_days = sla_targets[priority_name] || default_sla
            
            # Calculate actual resolution time (ensure non-negative)
            resolution_time = [(issue.closed_on.to_date - issue.created_on.to_date).to_i, 0].max
            
            # Check if issue was resolved within SLA target
            compliant_count += 1 if resolution_time <= target_days
          end
        rescue => e
          # Log error and continue with next issue
          Rails.logger.error "Error calculating SLA compliance for issue ##{issue.id}: #{e.message}"
          next
        end
      end
      
      # Calculate percentage of compliant issues
      return 0 if total_count == 0
      ((compliant_count.to_f / total_count) * 100).round(1)
    rescue => e
      # Log error and return 0
      Rails.logger.error "Error in calculate_sla_compliance: #{e.message}"
      return 0
    end
  end
  
  def calculate_time_in_status(issues)
    return {} if issues.empty?
    
    # Initialize hash to store average time in each status
    time_in_status = {}
    
    # Get all statuses
    IssueStatus.all.each do |status|
      time_in_status[status.id] = {
        name: status.name,
        avg_time: 0,
        count: 0
      }
    end
    
    # Calculate time spent in each status
    issues.each do |issue|
      begin
        # Get all status changes from journals
        # Use JournalDetail model directly to find status changes
        status_journals = Journal.joins(:details)
                                .where(journalized_id: issue.id, journalized_type: 'Issue')
                                .where("journal_details.prop_key = 'status_id'")
                                .order(created_on: :asc)
                                .to_a
        
        # Skip if no status changes
        next if status_journals.empty?
        
        # Track time in each status
        current_status_id = issue.status_id
        last_change_date = issue.created_on.to_date
        
        status_journals.each do |journal|
          # Calculate days spent in previous status
          days_in_status = [(journal.created_on.to_date - last_change_date).to_i, 0].max
          
          # Update time for previous status if it exists in our hash
          if time_in_status.key?(current_status_id)
            time_in_status[current_status_id][:avg_time] += days_in_status
            time_in_status[current_status_id][:count] += 1
          end
          
          # Find the status_id detail in this journal
          begin
            # Try to find the status change detail
            detail = JournalDetail.where(journal_id: journal.id, prop_key: 'status_id').first
            if detail
              current_status_id = detail.value.to_i
            end
          rescue => e
            # If there's an error, just continue with current status
            Rails.logger.error "Error finding status detail: #{e.message}"
          end
          
          last_change_date = journal.created_on.to_date
        end
        
        # Add time for current status (if issue is still open)
        if !IssueStatus.closed_ids.include?(issue.status_id)
          days_in_current_status = [(Date.today - last_change_date).to_i, 0].max
          if time_in_status.key?(current_status_id)
            time_in_status[current_status_id][:avg_time] += days_in_current_status
            time_in_status[current_status_id][:count] += 1
          end
        end
      rescue => e
        # Log error and continue with next issue
        Rails.logger.error "Error calculating time in status for issue ##{issue.id}: #{e.message}"
        next
      end
    end
    
    # Calculate averages
    time_in_status.each do |status_id, data|
      if data[:count] > 0
        data[:avg_time] = (data[:avg_time].to_f / data[:count]).round(1)
      end
    end
    
    time_in_status
  end

  def calculate_burn_down_data(start_date, end_date)
    total_issues = Issue.where(created_on: start_date..end_date).count
    daily_counts = {}
    (start_date..end_date).each do |date|
      daily_counts[date] = Issue.where(created_on: start_date..date).count
    end
    daily_counts
  end
  
  def burn_down
    # Implementation for burn down report
  end
  
  def project_specific
    @project = Project.find(params[:project_id]) if params[:project_id].present?
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.month.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    if @project
      # Get project-specific data
      @issues = @project.issues.where(created_on: @start_date..@end_date)
      @open_issues = @issues.open
      @closed_issues = @issues.closed
      
      # Calculate statistics
      @issue_status_distribution = @issues.group(:status).count
      @issue_priority_distribution = @issues.group(:priority).count
      @issue_activity = @issues.group('DATE(created_on)').count
      
      # Prepare data for charts
      @status_chart_data = @issue_status_distribution.map { |status, count| [status.name, count] }
      @activity_chart_data = @issue_activity.map { |date, count| [date.to_date.to_s, count] }.sort_by(&:first)
      
      respond_to do |format|
        format.html
        format.json { render json: { status_distribution: @issue_status_distribution, activity: @activity_chart_data } }
      end
    end
  end
  
  def progress
    @project = Project.find(params[:project_id]) if params[:project_id].present?
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.month.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    if @project
      # Get progress data
      @versions = @project.versions.where("effective_date >= ?", @start_date)
      @completed_versions = @versions.select(&:completed?).sort_by(&:effective_date)
      @upcoming_versions = @versions.reject(&:completed?).sort_by(&:effective_date)
      
      # Calculate progress metrics
      @total_issues = @project.issues.where(created_on: @start_date..@end_date).count
      @completed_issues = @project.issues.closed.where(closed_on: @start_date..@end_date).count
      @completion_rate = @total_issues > 0 ? (@completed_issues.to_f / @total_issues * 100).round(2) : 0
      
      # Prepare data for charts
      @progress_data = []
      @versions.each do |version|
        @progress_data << {
          name: version.name,
          total: version.fixed_issues.count,
          closed: version.closed_pourcent,
          effective_date: version.effective_date
        }
      end
      
      respond_to do |format|
        format.html
        format.json { render json: { progress_data: @progress_data } }
      end
    end
  end
  
  def export_project_report
    @project = Project.find(params[:project_id])
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.month.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    # Generate CSV data
    csv_data = CSV.generate do |csv|
      csv << ["Project: #{@project.name}", "Period: #{@start_date} to #{@end_date}"]
      csv << []
      csv << ["Issue ID", "Tracker", "Status", "Priority", "Subject", "Created On", "Updated On", "Closed On"]
      
      @project.issues.where(created_on: @start_date..@end_date).find_each do |issue|
        csv << [
          issue.id,
          issue.tracker.name,
          issue.status.name,
          issue.priority.name,
          issue.subject,
          issue.created_on,
          issue.updated_on,
          issue.closed_on
        ]
      end
    end
    
    send_data csv_data, 
              type: 'text/csv; charset=utf-8; header=present', 
              disposition: "attachment; filename=project_report_#{@project.identifier}_#{Date.today}.csv"
  end
  
  def export_progress_report
    @project = Project.find(params[:project_id])
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.month.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    # Generate CSV data
    csv_data = CSV.generate do |csv|
      csv << ["Progress Report for #{@project.name}", "Period: #{@start_date} to #{@end_date}"]
      csv << []
      csv << ["Version", "Total Issues", "% Complete", "Due Date", "Status"]
      
      @project.versions.where("effective_date >= ?", @start_date).each do |version|
        csv << [
          version.name,
          version.fixed_issues.count,
          "#{version.closed_pourcent}%",
          version.effective_date,
          version.completed? ? 'Completed' : 'In Progress'
        ]
      end
    end
    
    send_data csv_data, 
              type: 'text/csv; charset=utf-8; header=present', 
              disposition: "attachment; filename=progress_report_#{@project.identifier}_#{Date.today}.csv"
  end
  
  private
  
  def issues_by_project_and_assignee
    # Initialize @projects first to ensure it's never nil
    @projects = Project.visible.sorted.to_a
    
    # Set default dates
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.month.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
    
    # Get the selected project if any
    @selected_project = if params[:project_id].present?
      @projects.detect { |p| p.id == params[:project_id].to_i }
    end
    
    # Get all users who are assigned to issues
    @assignees = User.active.sorted
    
    # Initialize report data as an empty hash
    @report_data = {}
    
    begin
      # Base scope for issues
      issues_scope = Issue.visible
      issues_scope = issues_scope.where(project_id: @selected_project.id) if @selected_project
      issues_scope = issues_scope.where("#{Issue.table_name}.created_on BETWEEN ? AND ?", @start_date, @end_date + 1.day)
      
      # Group issues by project and assignee
      @report_data = issues_scope
        .joins(:assigned_to, :project)
        .group('projects.name', 'users.firstname', 'users.lastname')
        .select('projects.name as project_name, users.firstname, users.lastname, COUNT(issues.id) as issue_count')
        .order('projects.name, users.lastname, users.firstname')
        .each_with_object({}) do |issue, hash|
          project_name = issue.project_name
          assignee_name = "#{issue.firstname} #{issue.lastname}".strip
          hash[project_name] ||= {}
          hash[project_name][assignee_name] = issue.issue_count
        end
    rescue => e
      logger.error "Error generating project/assignee report: #{e.message}"
      logger.error e.backtrace.join("\n")
      @report_data = {}
    end
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_issues_by_project_assignee_csv, filename: "issues_by_project_assignee_#{Date.today}.csv" }
    end
  end
  
  def export_issues_by_project_and_assignee
    issues_by_project_and_assignee
  end
  
  private
  
  # Default color palette for charts
  CHART_COLORS = [
    '#3498db', '#2ecc71', '#e74c3c', '#f1c40f', '#9b59b6',
    '#1abc9c', '#e67e22', '#34495e', '#95a5a6', '#d35400',
    '#27ae60', '#c0392b', '#8e44ad', '#16a085', '#f39c12'
  ].freeze

  def prepare_chart_data
    @chart_data = {}
    
    # Issues by status chart
    status_data = @issue_stats[:issues_by_status].map.with_index do |(status, count), index|
      color_index = index % CHART_COLORS.size
      { status: status.name, count: count, color: CHART_COLORS[color_index] }
    end
    
    @chart_data[:issues_by_status] = {
      labels: status_data.map { |d| d[:status] },
      datasets: [{
        data: status_data.map { |d| d[:count] },
        backgroundColor: status_data.map { |d| d[:color] },
        borderWidth: 1
      }]
    }
    
    # Issues by priority chart
    priority_data = @issue_stats[:issues_by_priority].map.with_index do |(priority, count), index|
      color_index = (index + 5) % CHART_COLORS.size  # Offset index to get different colors
      { priority: priority.name, count: count, color: CHART_COLORS[color_index] }
    end
    
    @chart_data[:issues_by_priority] = {
      labels: priority_data.map { |d| d[:priority] },
      datasets: [{
        data: priority_data.map { |d| d[:count] },
        backgroundColor: priority_data.map { |d| d[:color] },
        borderWidth: 1
      }]
    }
    
    # Issues created over time (last 30 days)
    issues_by_day = Issue.visible.where('issues.created_on BETWEEN ? AND ?', @start_date, @end_date)
                        .group('DATE(issues.created_on)')
                        .count
    
    @chart_data[:issues_over_time] = {
      labels: (@start_date..@end_date).map { |date| date.strftime('%Y-%m-%d') },
      datasets: [{
        label: 'Issues Created',
        data: (@start_date..@end_date).map { |date| issues_by_day[date.to_s] || 0 },
        borderColor: '#3498db',
        backgroundColor: 'rgba(52, 152, 219, 0.1)',
        fill: true,
        tension: 0.3
      }]
    }
    
    # Users by role chart
    role_data = @user_stats[:users_by_role].map.with_index do |(role_name, count), index|
      color_index = (index * 2) % CHART_COLORS.size  # Spread out colors for better distinction
      { role: role_name, count: count, color: CHART_COLORS[color_index] }
    end
    
    @chart_data[:users_by_role] = {
      labels: role_data.map { |d| d[:role] },
      datasets: [{
        data: role_data.map { |d| d[:count] },
        backgroundColor: role_data.map { |d| d[:color] },
        borderWidth: 1
      }]
    }
  end

  def load_projects
    @projects = Project.visible.sorted
  end
  
  def generate_issues_by_project_assignee_csv
    CSV.generate do |csv|
      # Header
      csv << ["Project", "Assignee", "Number of Issues"]
      
      # Data rows
      @report_data.each do |project, assignees|
        assignees.each do |assignee, count|
          csv << [project, assignee, count]
        end
      end
    end
  end
  
  # Other private methods...
  
end
