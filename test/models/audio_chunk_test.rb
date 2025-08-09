require "test_helper"

class AudioChunkTest < ActiveSupport::TestCase
  test "validates presence of required fields" do
    chunk = AudioChunk.new
    assert_not chunk.valid?
    assert_includes chunk.errors[:session_id], "can't be blank"
    assert_includes chunk.errors[:data], "can't be blank"
    assert_includes chunk.errors[:sequence], "can't be blank"
  end

  test "validates uniqueness of sequence within session" do
    chunk1 = AudioChunk.create!(session_id: "test-123", data: "data1", sequence: 0)
    chunk2 = AudioChunk.new(session_id: "test-123", data: "data2", sequence: 0)

    assert_not chunk2.valid?
    assert_includes chunk2.errors[:sequence], "has already been taken"
  end

  test "ready_for_transcription returns 30 unprocessed chunks" do
    session_id = "test-session"

    # Create 35 chunks
    35.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: "chunk#{i}",
        sequence: i,
        processed: i < 5 # First 5 are processed
      )
    end

    ready_chunks = AudioChunk.ready_for_transcription(session_id)

    assert_equal 30, ready_chunks.count
    assert_equal 5, ready_chunks.first.sequence
    assert_equal 34, ready_chunks.last.sequence
  end
end
