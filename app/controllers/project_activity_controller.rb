class ProjectActivityController < ApplicationController
  before_action :find_project, :authorize

  def index
    @project = Project.find(params[:project_id])
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

    @issues = @project.issues.includes(:author, :assigned_to)
    @issue_counts = @issues.group_by { |i| i.created_on.to_date }
    @status_counts = @issues.group_by(&:status_id)

    @daily_activities = {}
    (@start_date..@end_date).each do |date|
      @daily_activities[date] = {
        issues_created: @issue_counts[date].try(:count) || 0,
        issues_closed: @issues.where(updated_on: date, status_id: IssueStatus.closed_ids).count
      }
    end

    @monthly_activities = {}
    (@start_date.beginning_of_month..@end_date.end_of_month).each_slice(1.month).each do |range|
      month = range.first
      @monthly_activities[month] = {
        issues_created: @issues.where(created_on: month.beginning_of_month..month.end_of_month).count,
        issues_closed: @issues.where(updated_on: month.beginning_of_month..month.end_of_month, status_id: IssueStatus.closed_ids).count
      }
    end
  end
end
