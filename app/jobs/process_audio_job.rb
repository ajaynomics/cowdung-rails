class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence, mode = "rolling")
    Rails.logger.info "Processing audio for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"

    # Get or create session transcript
    session_transcript = SessionTranscript.find_or_create_by!(session_id: session_id)

    # Get chunks for this batch
    chunks = AudioChunk.for_session(session_id)
                       .where(sequence: start_sequence..end_sequence)
                       .in_sequence

    return if chunks.empty?

    # Transcribe the chunks
    result = TranscriptionSegment.transcribe_chunks(chunks)

    if result[:success?]
      transcribed_text = result[:text]
      words = result[:words] || []

      # For rolling mode with context, extract only the new part
      if mode == "rolling" && start_sequence > 0
        # Use timestamps to find content after the context period
        context_chunks = [ start_sequence, 10 ].min  # Up to 10s of context
        context_duration = context_chunks * 1.0  # seconds

        # Find words that start after the context period
        new_words = words.select { |w| w["start"] && w["start"] >= context_duration }

        if new_words.any?
          new_text = new_words.map { |w| w["word"] }.join(" ").strip
        else
          # Fallback: smart deduplication based on existing transcript
          existing_text = session_transcript.current_text.to_s.strip

          if existing_text.present?
            # Get the last 50 chars of existing transcript for comparison
            tail_length = [ existing_text.length, 50 ].min
            existing_tail = existing_text[-tail_length..]

            # Find where the existing text ends in the new transcription
            overlap_index = transcribed_text.index(existing_tail)

            if overlap_index
              # Extract only the portion after the overlap
              new_text = transcribed_text[(overlap_index + existing_tail.length)..]&.strip || ""
            else
              # No clear overlap found - be conservative and take less
              new_text = transcribed_text.split(" ").last(10).join(" ")
            end
          else
            # No existing text, use all of it
            new_text = transcribed_text
          end
        end
      else
        # First transcription or final mode - use all text
        new_text = transcribed_text
      end

      # Update the session transcript only if we have new content
      if new_text.present? && new_text.strip.length > 0
        session_transcript.update!(
          current_text: (session_transcript.current_text.to_s + " " + new_text).strip
        )

        # Broadcast the update
        ActionCable.server.broadcast(
          "detector_#{session_id}",
          {
            type: "transcription",
            text: new_text,
            narrative_text: session_transcript.current_text.strip,
            timestamp: Time.current
          }
        )

        Rails.logger.info "✅ Added to transcript: #{new_text.truncate(100)}"
      else
        Rails.logger.info "ℹ️  No new content to add"
      end

      # Clean up old chunks (keep last 60 seconds)
      if end_sequence > 60
        AudioChunk.for_session(session_id)
                  .where("sequence < ?", end_sequence - 60)
                  .destroy_all
      end
    else
      Rails.logger.error "❌ Transcription failed: #{result[:error]}"
    end
  end
end
