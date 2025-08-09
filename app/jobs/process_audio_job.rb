class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence)
    Rails.logger.info "Processing audio chunks for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"

    # Get chunks for this batch
    chunks = AudioChunk.for_session(session_id)
                       .where(sequence: start_sequence..end_sequence)
                       .in_sequence

    if chunks.empty?
      Rails.logger.warn "No chunks found for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"
      return
    end

    Rails.logger.info "Found #{chunks.count} chunks to process"

    # Transcribe the chunks
    result = TranscriptionSegment.transcribe_chunks(chunks)

    if result[:success?]
      # Save the transcription
      segment = TranscriptionSegment.create!(
        session_id: session_id,
        text: result[:text],
        start_sequence: start_sequence,
        end_sequence: end_sequence,
        duration: chunks.count # Approximate duration in seconds
      )

      # Broadcast the transcription to the frontend
      ActionCable.server.broadcast(
        "audio_transcription_#{session_id}",
        {
          type: "transcription",
          text: result[:text],
          start_sequence: start_sequence,
          end_sequence: end_sequence,
          timestamp: Time.current
        }
      )

      # Delete processed chunks to save space (marking as processed is redundant)
      chunks.destroy_all

      Rails.logger.info "✅ Transcription complete for session #{session_id}: #{result[:text].truncate(100)}"
    else
      Rails.logger.error "❌ Transcription failed for session #{session_id}: #{result[:error]}"
      # Optionally retry or notify
    end
  end
end
