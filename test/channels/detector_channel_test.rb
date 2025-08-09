require "test_helper"

class DetectorChannelTest < ActionCable::Channel::TestCase
  test "subscribes to detector stream" do
    subscribe session_id: "test-session-123"

    assert subscription.confirmed?
    assert_has_stream "detector_test-session-123"
  end

  test "receives audio data and creates chunk" do
    subscribe session_id: "test-session-456"

    assert_difference "AudioChunk.count", 1 do
      perform :receive_audio, audio_chunk: "base64audiodata"
    end

    chunk = AudioChunk.last
    assert_equal "test-session-456", chunk.session_id
    assert_equal "base64audiodata", chunk.data
    assert_equal 0, chunk.sequence
  end

  test "creates chunks with proper sequence" do
    subscribe session_id: "test-session-789"

    # Create first chunk
    perform :receive_audio, audio_chunk: "chunk1"
    chunk1 = AudioChunk.last
    assert_equal 0, chunk1.sequence

    # Create second chunk
    perform :receive_audio, audio_chunk: "chunk2"
    chunk2 = AudioChunk.last
    assert_equal 1, chunk2.sequence

    # Verify both chunks exist
    assert_equal 2, AudioChunk.where(session_id: "test-session-789").count
  end

  test "unsubscribes cleanly" do
    subscribe session_id: "test-session-789"
    assert subscription.confirmed?

    unsubscribe
    assert_no_streams
  end
end
