require 'test_helper'

class OperationsControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get operations_home_url
    assert_response :success
  end

end
