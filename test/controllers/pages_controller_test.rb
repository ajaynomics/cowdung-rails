require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get audio" do
    get audio_path
    assert_response :success
  end

  test "should get greeting" do
    skip "Requires OpenAI API key - test manually in development"

    get greeting_path
    assert_response :success
    # Should either show a greeting or an error message
    assert response.body.include?("How are you today?")
  end
end
