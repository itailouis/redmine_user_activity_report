namespace :redmine do
  namespace :plugins do
    namespace :user_activity_report do
      desc 'Create daily records of user activity in the database'
      task :record_daily_activity => :environment do
        today = Date.today

        puts "Recording user activity for #{today}..."

        User.active.sorted.each do |user|
          # Skip creating a record if one already exists for today
          next if UserActivityHistory.where(user_id: user.id, activity_date: today).exists?

          # Get issue counts
          open_count = Issue.visible.where(assigned_to_id: user.id).open.count
          closed_count = Issue.visible.where(
            status_id: IssueStatus.where(is_closed: true).pluck(:id),
            assigned_to_id: user.id
          ).count
          total_count = open_count + closed_count

          # Get project-specific data
          projects_summary = {}

          Project.all.each do |project|
            next unless user.allowed_to?(:view_issues, project)

            project_open_count = Issue.visible.where(
              assigned_to_id: user.id,
              project_id: project.id
            ).open.count

            project_closed_count = Issue.visible.where(
              assigned_to_id: user.id,
              project_id: project.id,
              status_id: IssueStatus.where(is_closed: true).pluck(:id)
            ).count

            project_total = project_open_count + project_closed_count

            # Skip projects with no issues
            next if project_total == 0

            projects_summary[project.id] = {
              name: project.name,
              open_count: project_open_count,
              closed_count: project_closed_count,
              total_count: project_total
            }
          end

          # Create the history record
          history = UserActivityHistory.new(
            user_id: user.id,
            activity_date: today,
            last_login_on: user.last_login_on,
            open_issues_count: open_count,
            closed_issues_count: closed_count,
            total_issues_count: total_count,
            projects_summary: projects_summary
          )

          if history.save
            puts "  - Recorded activity for #{user.name}"
          else
            puts "  - Error recording activity for #{user.name}: #{history.errors.full_messages.join(', ')}"
          end
        end

        puts "Daily activity recording complete."
      end
    end
  end
end