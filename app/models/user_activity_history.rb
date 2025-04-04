class UserActivityHistory < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true
  validates :activity_date, presence: true
  validates :activity_date, uniqueness: { scope: :user_id }

  # Fixed serialization syntax for older Rails versions
  serialize :projects_summary

  # Get the latest activity record for a user
  def self.latest_for_user(user_id)
    where(user_id: user_id).order(activity_date: :desc).first
  end

  # Get all records for a specific date
  def self.for_date(date)
    where(activity_date: date)
  end

  # Get a date range of records for a user
  def self.date_range_for_user(user_id, start_date, end_date)
    where(user_id: user_id).where("activity_date BETWEEN ? AND ?", start_date, end_date).order(activity_date: :asc)
  end
end