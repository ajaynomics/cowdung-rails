require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get audio" do
    get audio_path
    assert_response :success
  end

  test "should get greeting" do
    get greeting_path
    assert_response :success
    assert_select "h1", "AI Greeting"
    assert_select "p", text: /You asked: "How are you today\?"/
  end
end
