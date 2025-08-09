require "application_system_test_case"

class AudioRecordingTest < ApplicationSystemTestCase
  test "user can access audio recording page" do
    visit audio_path

    assert_text "Audio Recorder"
    assert_button "Start Recording"
    assert_text "Click to record 10 seconds of audio"
  end
end
