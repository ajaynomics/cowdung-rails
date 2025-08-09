require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get audio" do
    get audio_path
    assert_response :success
  end

  test "greeting page displays AI response" do
    get greeting_path
    assert_response :success
    assert_select "h1", "AI Greeting"
    assert_select "p", text: /You asked: "How are you today\?"/
    
    # The response should contain the AI's greeting
    assert_select ".bg-gray-50 p" do |elements|
      response_text = elements.first.text.strip
      assert_not response_text.include?("Error:")
      assert response_text.present?
    end
  end
end
