class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence, mode = "rolling")
    Rails.logger.info "Processing audio for session #{session_id}, sequences #{start_sequence}-#{end_sequence}, mode: #{mode}"

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
        existing_text = session_transcript.current_text.to_s.strip

        # Simple approach: store the last processed text to avoid duplication
        last_processed = session_transcript.last_processed_text || ""

        if transcribed_text == last_processed
          # Exact duplicate - skip it
          new_text = ""
          Rails.logger.info "Skipping duplicate transcription"
        elsif existing_text.present? && transcribed_text.start_with?(existing_text)
          # The transcription starts with our existing text - take what's after
          new_text = transcribed_text[existing_text.length..].strip
          Rails.logger.info "Found clean continuation, adding: #{new_text.truncate(50)}"
        elsif existing_text.present?
          # Try to find overlap
          # Split existing text into words and look for where it ends in the new transcription
          existing_words = existing_text.split(/\s+/)

          # Try different tail lengths to find overlap
          overlap_found = false
          [ 10, 8, 6, 4, 2 ].each do |word_count|
            next if existing_words.length < word_count

            tail_words = existing_words.last(word_count).join(" ")
            if transcribed_text.include?(tail_words)
              # Found where the existing text ends
              index = transcribed_text.rindex(tail_words)
              new_text = transcribed_text[(index + tail_words.length)..].strip
              overlap_found = true
              Rails.logger.info "Found overlap with #{word_count} words, adding: #{new_text.truncate(50)}"
              break
            end
          end

          unless overlap_found
            # No clear overlap - this might be completely new content
            new_text = transcribed_text
            Rails.logger.info "No overlap found, using full text"
          end
        else
          # First transcription
          new_text = transcribed_text
        end

        # Store what we processed to detect exact duplicates next time
        session_transcript.update_column(:last_processed_text, transcribed_text)
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
