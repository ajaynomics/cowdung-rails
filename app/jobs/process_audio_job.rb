class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence)
    Rails.logger.info "Processing audio chunks for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"

    # Get or create transcription session
    transcription_session = TranscriptionSession.find_or_create_by!(session_id: session_id)

    # Get chunks for this batch
    chunks = AudioChunk.for_session(session_id)
                       .where(sequence: start_sequence..end_sequence)
                       .in_sequence

    if chunks.empty?
      Rails.logger.warn "No chunks found for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"
      return
    end

    Rails.logger.info "Found #{chunks.count} chunks to process"

    # Check for overlap with previous windows
    overlap_size = transcription_session.overlap_size(start_sequence, end_sequence)
    Rails.logger.info "Overlap size with previous windows: #{overlap_size} chunks"

    # Transcribe the chunks
    result = TranscriptionSegment.transcribe_chunks(chunks)

    if result[:success?]
      transcribed_text = result[:text]
      words = result[:words] || []
      segments = result[:segments] || []

      # Log timestamp information if available
      if words.any?
        Rails.logger.info "Transcription has #{words.length} words with timestamps"
      end

      # Handle deduplication if this window overlaps with previous ones
      if overlap_size > 0 && transcription_session.last_processed_text.present?
        Rails.logger.info "Deduplicating overlapping transcription"
        # Find the new content by removing the overlap
        # Use timestamp data if available for more accurate deduplication
        new_text = if words.any?
          extract_new_content_with_timestamps(
            transcription_session.last_processed_text,
            transcribed_text,
            words,
            overlap_size
          )
        else
          extract_new_content(
            transcription_session.last_processed_text,
            transcribed_text,
            overlap_size
          )
        end

        # Only broadcast if there's new content
        if new_text.present?
          broadcast_text = new_text
        else
          Rails.logger.info "No new content in overlapping window"
          transcription_session.add_processed_range(start_sequence, end_sequence)
          return
        end
      else
        # No overlap, use full transcription
        broadcast_text = transcribed_text
      end

      # Save the transcription segment
      segment = TranscriptionSegment.create!(
        session_id: session_id,
        text: transcribed_text,
        start_sequence: start_sequence,
        end_sequence: end_sequence,
        duration: chunks.count
      )

      # Broadcast only the new content
      ActionCable.server.broadcast(
        "detector_#{session_id}",
        {
          type: "transcription",
          text: broadcast_text,
          start_sequence: start_sequence,
          end_sequence: end_sequence,
          timestamp: Time.current,
          is_partial: overlap_size > 0
        }
      )

      # Update session tracking
      transcription_session.update!(last_processed_text: transcribed_text)
      transcription_session.add_processed_range(start_sequence, end_sequence)

      # Only delete non-overlapping chunks
      # Keep the last chunk for next window's overlap
      if end_sequence > 0
        chunks_to_delete = chunks[0...-1]  # Keep the last chunk
        chunks_to_delete.each(&:destroy)
      end

      Rails.logger.info "✅ Transcription complete for session #{session_id}: #{broadcast_text.truncate(100)}"
    else
      Rails.logger.error "❌ Transcription failed for session #{session_id}: #{result[:error]}"
    end
  end

  private

  def extract_new_content(previous_text, current_text, overlap_chunks)
    # Simple approach: find common suffix/prefix
    # In production, use more sophisticated algorithm like LCS

    # Estimate overlap character count (rough estimate)
    estimated_overlap_chars = overlap_chunks * 50  # ~50 chars per second of speech

    # Look for matching end of previous with start of current
    min_match_length = [ estimated_overlap_chars / 2, 20 ].max

    # Find the longest matching suffix of previous with prefix of current
    best_match_length = 0
    (min_match_length...[ previous_text.length, current_text.length ].min).each do |length|
      if previous_text[-length..] == current_text[0...length]
        best_match_length = length
      end
    end

    if best_match_length > 0
      # Return the new content after the match
      current_text[best_match_length..]
    else
      # No clear match found, return full text but log warning
      Rails.logger.warn "Could not find overlap match, returning full text"
      current_text
    end
  end

  def extract_new_content_with_timestamps(previous_text, current_text, words, overlap_chunks)
    # Use timestamp data for more accurate deduplication
    # Find where the overlap period starts based on timestamps

    overlap_duration = overlap_chunks * 1.0  # seconds

    # Find words that start after the overlap period
    new_words = words.select do |word|
      word["start"] && word["start"] >= overlap_duration
    end

    if new_words.any?
      # Reconstruct text from new words only
      new_text = new_words.map { |w| w["word"] }.join(" ").strip
      Rails.logger.info "Extracted #{new_words.length} new words using timestamps"
      new_text
    else
      # Fall back to text-based approach if no new words found
      Rails.logger.info "No words found after overlap period, using text-based approach"
      extract_new_content(previous_text, current_text, overlap_chunks)
    end
  end
end
