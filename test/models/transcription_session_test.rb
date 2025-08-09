require "test_helper"

class TranscriptionSessionTest < ActiveSupport::TestCase
  test "tracks processed sequence ranges" do
    session = TranscriptionSession.create!(session_id: "test-123")

    # Add first range
    session.add_processed_range(0, 2)
    assert_equal [ [ 0, 2 ] ], session.processed_sequences_array

    # Add non-overlapping range
    session.add_processed_range(4, 6)
    assert_equal [ [ 0, 2 ], [ 4, 6 ] ], session.processed_sequences_array
  end

  test "detects overlapping ranges" do
    session = TranscriptionSession.create!(session_id: "test-456")
    session.add_processed_range(0, 2)

    # Check various overlap scenarios
    assert session.overlaps_with_previous?(1, 3)  # Partial overlap
    assert session.overlaps_with_previous?(0, 2)  # Exact match
    assert session.overlaps_with_previous?(0, 5)  # Contains previous
    assert_not session.overlaps_with_previous?(3, 5)  # No overlap
  end

  test "calculates overlap size correctly" do
    session = TranscriptionSession.create!(session_id: "test-789")
    session.add_processed_range(0, 2)
    session.add_processed_range(4, 6)

    # Test overlap calculations
    assert_equal 2, session.overlap_size(1, 3)  # Overlaps [1,2] with [0,2]
    assert_equal 1, session.overlap_size(2, 4)  # Overlaps [2] with [0,2] and [4] with [4,6]
    assert_equal 0, session.overlap_size(7, 9)  # No overlap
    assert_equal 3, session.overlap_size(0, 5)  # Full overlap with [0,2]
  end

  test "validates session_id uniqueness" do
    TranscriptionSession.create!(session_id: "unique-123")
    duplicate = TranscriptionSession.new(session_id: "unique-123")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:session_id], "has already been taken"
  end
end
