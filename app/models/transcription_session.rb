class TranscriptionSession < ApplicationRecord
  validates :session_id, presence: true, uniqueness: true

  # Track processed sequence ranges to detect overlaps
  def processed_sequences_array
    return [] if processed_sequences.blank?
    JSON.parse(processed_sequences)
  rescue JSON::ParserError
    []
  end

  def add_processed_range(start_seq, end_seq)
    ranges = processed_sequences_array
    ranges << [ start_seq, end_seq ]
    update!(processed_sequences: ranges.to_json)
  end

  def overlaps_with_previous?(start_seq, end_seq)
    processed_sequences_array.any? do |range_start, range_end|
      # Check if there's any overlap
      start_seq <= range_end && end_seq >= range_start
    end
  end

  def overlap_size(start_seq, end_seq)
    max_overlap = 0
    processed_sequences_array.each do |range_start, range_end|
      if start_seq <= range_end && end_seq >= range_start
        # Calculate overlap size
        overlap_start = [ start_seq, range_start ].max
        overlap_end = [ end_seq, range_end ].min
        overlap = overlap_end - overlap_start + 1
        max_overlap = [ max_overlap, overlap ].max
      end
    end
    max_overlap
  end
end
