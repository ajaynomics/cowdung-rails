class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence)
    Rails.logger.info "Processing audio chunks for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"

    # Get the chunks to process
    chunks = AudioChunk.for_session(session_id)
                      .where(sequence: start_sequence..end_sequence)
                      .in_sequence

    if chunks.empty?
      Rails.logger.warn "No chunks found for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"
      return
    end

    Rails.logger.info "Found #{chunks.count} chunks to process"

    # Log chunk details for debugging
    chunks.each_with_index do |chunk, idx|
      data = Base64.decode64(chunk.data)
      hex = data[0..10].unpack1("H*").upcase.scan(/../).join(" ")
      Rails.logger.info "Chunk #{idx} header: #{hex}"
    end

    # Transcribe the audio
    service = WhisperService.new
    result = service.transcribe_chunks(chunks)

    if result.success?
      # Save the transcription
      segment = TranscriptionSegment.create!(
        session_id: session_id,
        text: result.text,
        start_sequence: start_sequence,
        end_sequence: end_sequence,
        duration: chunks.count # Approximate duration in seconds
      )

      # Mark chunks as processed
      chunks.update_all(processed: true)

      # Broadcast the transcription to the frontend
      ActionCable.server.broadcast(
        "detector_#{session_id}",
        {
          type: "transcription",
          text: result.text,
          start_sequence: start_sequence,
          end_sequence: end_sequence,
          timestamp: Time.current
        }
      )

      # Delete the processed audio chunks to save space
      chunks.destroy_all

      Rails.logger.info "✅ Transcription complete for session #{session_id}: #{result.text.truncate(100)}"
    else
      Rails.logger.error "❌ Transcription failed for session #{session_id}: #{result.error}"
      # Optionally retry or notify
    end
  end
end
