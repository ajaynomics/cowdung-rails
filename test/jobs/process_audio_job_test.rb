require "test_helper"

class ProcessAudioJobTest < ActiveJob::TestCase
  test "job processes chunks and creates transcription" do
    # Stub the OpenAI API call
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
      .to_return(
        status: 200,
        body: { text: "This is a test transcription" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Create test chunks
    session_id = "test-session"
    3.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: Base64.encode64("audio data #{i}"),
        sequence: i
      )
    end

    # Run the job
    assert_difference "TranscriptionSegment.count", 1 do
      ProcessAudioJob.perform_now(session_id, 0, 2)
    end

    # Verify transcription was created
    segment = TranscriptionSegment.last
    assert_equal "This is a test transcription", segment.text
    assert_equal 0, segment.start_sequence
    assert_equal 2, segment.end_sequence
  end
end
