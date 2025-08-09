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
          # Fallback: take the last portion of the text
          new_text = transcribed_text.split(" ").last(20).join(" ")
        end
      else
        # First transcription or final mode - use all text
        new_text = transcribed_text
      end

      # Update the session transcript
      session_transcript.update!(
        current_text: session_transcript.current_text.to_s + " " + new_text
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

      # Clean up old chunks (keep last 60 seconds)
      if end_sequence > 60
        AudioChunk.for_session(session_id)
                  .where("sequence < ?", end_sequence - 60)
                  .destroy_all
      end

      Rails.logger.info "✅ Added to transcript: #{new_text.truncate(100)}"
    else
      Rails.logger.error "❌ Transcription failed: #{result[:error]}"
    end
  end
end
