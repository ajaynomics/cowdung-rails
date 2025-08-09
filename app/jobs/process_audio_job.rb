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
        # First try timestamp-based extraction if we have word timings
        if words.any? && words.first["start"]
          # We process every 2 chunks, so new content starts after 10 seconds of context
          # (assuming 1 second per chunk and we keep up to 30 chunks of context)
          context_duration = 10.0  # seconds
          new_words = words.select { |w| w["start"] && w["start"] >= context_duration }

          if new_words.any?
            new_text = new_words.map { |w| w["word"] }.join(" ").strip
            Rails.logger.debug "Used timestamp extraction: #{new_text}"
          else
            new_text = ""
          end
        else
          # Fallback to text-based deduplication
          existing_text = session_transcript.current_text.to_s.strip

          if existing_text.present?
            # Find where existing content ends in the new transcription
            # Look for the last 30-100 chars of existing text
            search_lengths = [ 100, 80, 60, 40, 30, 20, 10 ]
            overlap_found = false

            search_lengths.each do |length|
              if existing_text.length <= length
                # Use the whole existing text if it's shorter than our search length
                search_text = existing_text
              else
                search_text = existing_text.last(length)
              end

              if transcribed_text.include?(search_text)
                # Found overlap! Extract only what comes after
                index = transcribed_text.rindex(search_text)
                new_text = transcribed_text[(index + search_text.length)..]&.strip || ""
                overlap_found = true
                Rails.logger.debug "Found overlap with #{length} chars, search: '#{search_text}', new text: '#{new_text.truncate(50)}'"
                break
              end
            end

            unless overlap_found
              # No overlap - might be completely new content
              new_text = transcribed_text
              Rails.logger.debug "No overlap found, using full text"
            end
          else
            # First transcription or no existing text
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
