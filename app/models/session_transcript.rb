class SessionTranscript < ApplicationRecord
  validates :session_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active processing completed] }

  before_validation :set_defaults

  # Structure for segments_data: Array of hashes with text, start_sequence, end_sequence, quality_level
  def segments
    return [] if segments_data.blank?
    JSON.parse(segments_data)
  rescue JSON::ParserError
    []
  end

  def add_segment(text, start_sequence, end_sequence, quality_level = "quick")
    current_segments = segments

    # Find if we're updating an existing segment range
    existing_index = current_segments.find_index do |seg|
      seg["start_sequence"] == start_sequence && seg["end_sequence"] == end_sequence
    end

    if existing_index
      # Update existing segment if new quality level is higher
      if quality_level == "quality" || current_segments[existing_index]["quality_level"] == "quick"
        current_segments[existing_index] = {
          "text" => text,
          "start_sequence" => start_sequence,
          "end_sequence" => end_sequence,
          "quality_level" => quality_level,
          "updated_at" => Time.current.iso8601
        }
      end
    else
      # Add new segment
      current_segments << {
        "text" => text,
        "start_sequence" => start_sequence,
        "end_sequence" => end_sequence,
        "quality_level" => quality_level,
        "created_at" => Time.current.iso8601
      }
    end

    # Sort by start sequence
    current_segments.sort_by! { |seg| seg["start_sequence"] }

    update!(segments_data: current_segments.to_json)
    rebuild_narrative_text
  end

  def rebuild_narrative_text
    # Rebuild the narrative by concatenating segments intelligently
    sorted_segments = segments.sort_by { |seg| seg["start_sequence"] }

    return if sorted_segments.empty?

    narrative_parts = []
    last_end_sequence = -1

    sorted_segments.each do |segment|
      # Skip if this segment is fully contained within a previous one
      next if segment["end_sequence"] <= last_end_sequence

      # If there's overlap, try to merge intelligently
      if segment["start_sequence"] <= last_end_sequence && narrative_parts.any?
        # Extract the new portion
        overlap_size = last_end_sequence - segment["start_sequence"] + 1

        # Simple approach: just append the new part
        # In production, use more sophisticated merging
        narrative_parts << segment["text"]
      else
        narrative_parts << segment["text"]
      end

      last_end_sequence = segment["end_sequence"]
    end

    # Join with spaces, clean up extra whitespace
    narrative = narrative_parts.join(" ").gsub(/\s+/, " ").strip

    update!(current_text: narrative)
  end

  def mark_quality_pass(up_to_sequence)
    update!(last_quality_pass_sequence: up_to_sequence)
  end

  def needs_quality_pass?(current_sequence)
    return true if last_quality_pass_sequence.nil?
    current_sequence - last_quality_pass_sequence >= 10 # Every 10 sequences
  end

  private

  def set_defaults
    self.status ||= "active"
    self.segments_data ||= "[]"
    self.current_text ||= ""
  end
end
