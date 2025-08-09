require "test_helper"

class DetectorChannelTest < ActionCable::Channel::TestCase
  include ActiveJob::TestHelper
  tests DetectorChannel
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

  test "receives PCM audio with format and sample rate" do
    subscribe session_id: "test-pcm-session"

    perform :receive_audio, {
      audio_chunk: "pcm16data",
      format: "pcm16",
      sample_rate: 48000
    }

    chunk = AudioChunk.last
    assert_equal "test-pcm-session", chunk.session_id
    assert_equal "pcm16data", chunk.data
    assert_equal "pcm16", chunk.format
    assert_equal 48000, chunk.sample_rate
  end

  test "defaults to pcm16 format when not specified" do
    subscribe session_id: "test-default-session"

    perform :receive_audio, audio_chunk: "pcmdata"

    chunk = AudioChunk.last
    assert_equal "pcm16", chunk.format
    assert_equal 44100, chunk.sample_rate
  end

  test "enqueues job with sliding window every 3 chunks" do
    subscribe session_id: "test-job-session"

    # First 2 chunks shouldn't trigger job
    2.times do |i|
      perform :receive_audio, audio_chunk: "chunk#{i}"
    end

    assert_no_enqueued_jobs

    # 3rd chunk (sequence 2) should trigger first job
    assert_enqueued_with(job: ProcessAudioJob, args: [ "test-job-session", 0, 2 ]) do
      perform :receive_audio, audio_chunk: "chunk2"
    end

    # 4th chunk (sequence 3) shouldn't trigger job
    perform :receive_audio, audio_chunk: "chunk3"
    assert_enqueued_jobs 1  # Still just one job

    # 5th chunk (sequence 4) should trigger second job with overlap
    assert_enqueued_with(job: ProcessAudioJob, args: [ "test-job-session", 2, 4 ]) do
      perform :receive_audio, audio_chunk: "chunk4"
    end

    # Verify sliding window pattern continues
    perform :receive_audio, audio_chunk: "chunk5"
    assert_enqueued_jobs 2  # Still just two jobs

    # 7th chunk (sequence 6) triggers third job
    assert_enqueued_with(job: ProcessAudioJob, args: [ "test-job-session", 4, 6 ]) do
      perform :receive_audio, audio_chunk: "chunk6"
    end
  end
end
