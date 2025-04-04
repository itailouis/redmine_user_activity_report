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

    add_index :user_activity_histories, [:user_id, :activity_date], unique: true
  end
end
