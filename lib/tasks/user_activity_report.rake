namespace :redmine do
  namespace :plugins do
    namespace :user_activity_report do
      desc 'Generate user activity report'
      task :generate => :environment do
        puts "Generating User Activity Report..."

        User.active.sorted.each do |user|
          puts "User: #{user.name} (#{user.login})"
          puts "Last login: #{user.last_login_on || 'Never'}"
          puts "Total issues: #{Issue.visible.where(:assigned_to_id => user.id).count}"
          puts "---"
        end

        puts "Report generation complete."
      end
    end
  end
end