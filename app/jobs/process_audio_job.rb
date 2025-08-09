class ProcessAudioJob < ApplicationJob
  queue_as :default

  def perform(session_id, start_sequence, end_sequence)
    Rails.logger.info "Processing audio chunks for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"

    # Get all chunks in range (including context chunks)
    all_chunks = AudioChunk.for_session(session_id)
                           .where(sequence: start_sequence..end_sequence)
                           .in_sequence

    if all_chunks.empty?
      Rails.logger.warn "No chunks found for session #{session_id}, sequences #{start_sequence}-#{end_sequence}"
      return
    end

    # Identify which chunks are new (last 10) vs context (first 2)
    new_chunks = all_chunks.select { |c| c.sequence > end_sequence - 10 }
    context_chunks = all_chunks - new_chunks

    Rails.logger.info "Found #{all_chunks.count} total chunks: #{context_chunks.count} context, #{new_chunks.count} new"

    # Log chunk details for debugging
    all_chunks.each_with_index do |chunk, idx|
      data = Base64.decode64(chunk.data)
      hex = data[0..10].unpack1("H*").upcase.scan(/../).join(" ")
      Rails.logger.info "Chunk #{idx} (seq #{chunk.sequence}) header: #{hex}"
    end

    # Transcribe all chunks (including context)
    service = WhisperService.new
    result = service.transcribe_chunks(all_chunks)

    if result.success?
      # Save the transcription
      segment = TranscriptionSegment.create!(
        session_id: session_id,
        text: result.text,
        start_sequence: start_sequence,
        end_sequence: end_sequence,
        duration: new_chunks.count # Approximate duration in seconds
      )

      # Mark only NEW chunks as processed (not context chunks)
      new_chunks.each { |chunk| chunk.update!(processed: true) }

      # Broadcast the transcription to the frontend
      ActionCable.server.broadcast(
        "detector_#{session_id}",
        {
          type: "transcription",
          text: result.text,
          start_sequence: new_chunks.first.sequence,
          end_sequence: new_chunks.last.sequence,
          timestamp: Time.current
        }
      )

      # Delete only the NEW processed audio chunks to save space
      # Keep context chunks as they might be needed for next batch
      new_chunks.each(&:destroy)

      Rails.logger.info "✅ Transcription complete for session #{session_id}: #{result.text.truncate(100)}"
    else
      Rails.logger.error "❌ Transcription failed for session #{session_id}: #{result.error}"
      # Optionally retry or notify
    end
  end
end
