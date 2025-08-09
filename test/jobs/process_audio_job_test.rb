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
    assert_difference "SessionTranscript.count", 1 do
      ProcessAudioJob.perform_now(session_id, 0, 2, "rolling")
    end

    # Verify session transcript was created
    transcript = SessionTranscript.find_by(session_id: session_id)
    assert_equal "This is a test transcription", transcript.current_text.strip
  end

  test "job handles rolling context mode" do
    # Stub the OpenAI API calls
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
      .to_return(
        { status: 200,
          body: {
            text: "Hello world",
            words: [
              { word: "Hello", start: 0.0, end: 0.5 },
              { word: "world", start: 0.5, end: 1.0 }
            ]
          }.to_json },
        { status: 200,
          body: {
            text: "Hello world this is a test",
            words: [
              { word: "Hello", start: 0.0, end: 0.5 },
              { word: "world", start: 0.5, end: 1.0 },
              { word: "this", start: 10.0, end: 10.3 },
              { word: "is", start: 10.3, end: 10.5 },
              { word: "a", start: 10.5, end: 10.7 },
              { word: "test", start: 10.7, end: 11.0 }
            ]
          }.to_json }
      )

    session_id = "test-rolling"

    # Create chunks
    15.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: Base64.encode64("audio data #{i}"),
        sequence: i,
        format: "pcm16",
        sample_rate: 44100
      )
    end

    # Process first batch
    ProcessAudioJob.perform_now(session_id, 0, 2, "rolling")

    # Process with rolling context
    ProcessAudioJob.perform_now(session_id, 5, 14, "rolling")

    # Verify transcript accumulated correctly
    transcript = SessionTranscript.find_by(session_id: session_id)
    assert_equal "Hello world this is a test", transcript.current_text.strip
  end
end
