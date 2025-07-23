class LikesController < ApplicationController
  before_action :require_login
  skip_before_action :verify_authenticity_token, only: [:toggle]

  # GET /user_activity_report/likes/count
  def count
    report_id = params[:report_id]
    report_type = params[:report_type]
    
    # Initialize session storage for likes if it doesn't exist
    session[:liked_reports] ||= {}
    
    # Get like count for this report
    like_count = session[:liked_reports]["#{report_type}:#{report_id}"].to_i
    
    render json: {
      count: like_count,
      liked: session[:liked_reports]["#{report_type}:#{report_id}"].present?
    }
  end
  
  # POST /user_activity_report/likes/toggle
  def toggle
    report_id = params[:report_id]
    report_type = params[:report_type]
    
    # Initialize session storage for likes if it doesn't exist
    session[:liked_reports] ||= {}
    
    # Toggle like status
    like_key = "#{report_type}:#{report_id}"
    if session[:liked_reports][like_key]
      session[:liked_reports][like_key] = nil
      liked = false
    else
      session[:liked_reports][like_key] = true
      liked = true
    end
    
    # Count total likes for this report
    like_count = session[:liked_reports].select { |k, v| k.start_with?("#{report_type}:#{report_id}") && v }.size
    
    render json: {
      success: true,
      count: like_count,
      liked: liked
    }
  end
  
  private
  
  def require_login
    unless User.current.logged?
      render json: { error: 'Authentication required' }, status: :unauthorized
      return false
    end
    true
  end
end
