require "test_helper"

class ProcessAudioJobTest < ActiveJob::TestCase
  test "job processes chunks and creates transcription" do
    # Stub the OpenAI API call with verbose response format
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
      .to_return(
        status: 200,
        body: {
          text: "This is a test transcription",
          words: [
            { word: "This", start: 0.0, end: 0.2 },
            { word: "is", start: 0.2, end: 0.4 },
            { word: "a", start: 0.4, end: 0.5 },
            { word: "test", start: 0.5, end: 0.8 },
            { word: "transcription", start: 0.8, end: 1.5 }
          ],
          segments: []
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Create test chunks
    session_id = "test-session"
    3.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: Base64.encode64("audio data #{i}"),
        sequence: i,
        format: "pcm16",
        sample_rate: 44100
      )
    end

    # Run the job
    assert_difference "TranscriptionSegment.count", 1 do
      assert_difference "TranscriptionSession.count", 1 do
        assert_difference "SessionTranscript.count", 1 do
          ProcessAudioJob.perform_now(session_id, 0, 2, "quick")
        end
      end
    end

    # Verify transcription was created
    segment = TranscriptionSegment.last
    assert_equal "This is a test transcription", segment.text
    assert_equal 0, segment.start_sequence
    assert_equal 2, segment.end_sequence

    # Verify transcription session was created and updated
    session = TranscriptionSession.find_by(session_id: session_id)
    assert_equal "This is a test transcription", session.last_processed_text
    assert_equal [ [ 0, 2 ] ], session.processed_sequences_array
  end

  test "job handles overlapping windows with deduplication" do
    # Stub the OpenAI API calls
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
      .to_return(
        { status: 200,
          body: {
            text: "Hello world this is",
            words: [
              { word: "Hello", start: 0.0, end: 0.5 },
              { word: "world", start: 0.5, end: 1.0 },
              { word: "this", start: 1.0, end: 1.3 },
              { word: "is", start: 1.3, end: 1.5 }
            ]
          }.to_json },
        { status: 200,
          body: {
            text: "this is a test",
            words: [
              { word: "this", start: 0.0, end: 0.3 },
              { word: "is", start: 0.3, end: 0.5 },
              { word: "a", start: 0.5, end: 0.7 },
              { word: "test", start: 0.7, end: 1.0 }
            ]
          }.to_json }
      )

    session_id = "test-overlap"

    # Create chunks for two overlapping windows
    5.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: Base64.encode64("audio data #{i}"),
        sequence: i,
        format: "pcm16",
        sample_rate: 44100
      )
    end

    # Process first window (0-2)
    ProcessAudioJob.perform_now(session_id, 0, 2, "quick")

    # Process overlapping window (2-4)
    ProcessAudioJob.perform_now(session_id, 2, 4, "quick")

    # Should have created 2 segments but detected overlap
    assert_equal 2, TranscriptionSegment.where(session_id: session_id).count

    # Verify session tracked both windows
    session = TranscriptionSession.find_by(session_id: session_id)
    assert_equal [ [ 0, 2 ], [ 2, 4 ] ], session.processed_sequences_array
    assert_equal "this is a test", session.last_processed_text
  end
end
