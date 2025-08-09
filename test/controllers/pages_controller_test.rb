require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "audio page renders with recording interface" do
    get audio_path
    assert_response :success
    assert_select "h1", "Audio Recorder"
    assert_select "button[data-audio-recorder-target='button']"
    assert_select "[data-controller='audio-recorder']"
  end

  test "greeting page renders and executes workflow" do
    get greeting_path
    assert_response :success

    # Page structure is correct
    assert_select "h1", "AI Greeting"
    assert_select "p", text: /You asked: "How are you today\?"/

    # Response area exists and contains content
    assert_select ".bg-gray-50 p" do |elements|
      assert elements.first.text.strip.present?, "Response area should contain text"
    end
  end
end
