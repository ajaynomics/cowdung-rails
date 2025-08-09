require "test_helper"

class DetectorChannelTest < ActionCable::Channel::TestCase
  test "subscribes to detector stream" do
    subscribe session_id: "test-session-123"

    assert subscription.confirmed?
    assert_has_stream "detector_test-session-123"
  end

  test "receives audio data" do
    subscribe session_id: "test-session-456"

    # Perform the receive_audio action
    perform :receive_audio, audio_chunk: "base64audiodata"

    # Just verify no errors are raised - we're only logging for now
    assert subscription.confirmed?
  end

  test "unsubscribes cleanly" do
    subscribe session_id: "test-session-789"
    assert subscription.confirmed?

    unsubscribe
    assert_no_streams
  end
end
