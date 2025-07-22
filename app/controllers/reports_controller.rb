class ReportsController < ApplicationController
  before_action :authorize

  def index
    # No need to set @reports anymore since the view is static
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
end
