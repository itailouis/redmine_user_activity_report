require File.expand_path('../../test_helper', __FILE__)

class UserActivityReportControllerTest < ActionController::TestCase
  fixtures :users, :projects, :issues

  def setup
    @request.session[:user_id] = 1 # Admin user
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:users)
  end

  def test_show
    get :show, params: { id: 2 }
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:user)
    assert_not_nil assigns(:issues_by_project)
  end
end