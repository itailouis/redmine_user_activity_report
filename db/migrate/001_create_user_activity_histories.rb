class CreateUserActivityHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :user_activity_histories do |t|
      t.integer :user_id, null: false
      t.date :activity_date, null: false
      t.datetime :last_login_on
      t.integer :open_issues_count, default: 0
      t.integer :closed_issues_count, default: 0
      t.integer :total_issues_count, default: 0
      t.text :projects_summary
      t.timestamps
    end
    
    create_table :project_overview_settings do |t|
      t.references :project, null: false, foreign_key: true
      t.json :dashboard_config
      t.boolean :enabled, default: true
      t.timestamps
    end
    
    add_index :project_overview_settings, :project_id, unique: true

    add_index :user_activity_histories, [:user_id, :activity_date], unique: true
  end
end
