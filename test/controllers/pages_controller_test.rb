require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get audio" do
    get audio_path
    assert_response :success
  end
end
