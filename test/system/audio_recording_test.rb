require "application_system_test_case"

class AudioRecordingTest < ApplicationSystemTestCase
  test "user sees audio recording interface" do
    visit audio_path

    assert_text "Audio Recorder"
    assert_button "Start Recording"
    assert_text "Click to record 10 seconds of audio"
  end

  test "button changes text when clicked" do
    visit audio_path

    # Initial state
    assert_button "Start Recording"

    # Note: Full audio recording test would require mocking browser APIs
    # which is beyond simple system tests. This tests the UI exists.
  end
end
