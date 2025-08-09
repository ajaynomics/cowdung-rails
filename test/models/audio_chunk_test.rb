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

  test "pcm_data returns decoded base64 data" do
    original_data = "test audio data"
    encoded_data = Base64.encode64(original_data)

    chunk = AudioChunk.create!(
      session_id: "test-123",
      data: encoded_data,
      sequence: 0
    )

    assert_equal original_data, chunk.pcm_data
  end

  test "stores format and sample_rate" do
    chunk = AudioChunk.create!(
      session_id: "test-123",
      data: "pcm_data",
      sequence: 0,
      format: "pcm16",
      sample_rate: 44100
    )

    assert_equal "pcm16", chunk.format
    assert_equal 44100, chunk.sample_rate
  end
end
