class DetectorChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]
    stream_from "detector_#{@session_id}"
  end

  def unsubscribed
    # Process any remaining chunks when user stops recording
    process_remaining_chunks
  end

  def receive_audio(data)
    return Rails.logger.error "No audio data in chunk!" if data["audio_chunk"].blank?
    # Save the audio chunk
    chunk = AudioChunk.create!(
      session_id: @session_id,
      data: data["audio_chunk"],
      sequence: next_sequence_number,
      format: data["format"] || "pcm16",
      sample_rate: data["sample_rate"] || 44100
    )

    # Transcribe with rolling context every 2 seconds
    # Keep last 30 seconds (30 chunks) for context, but focus on recent audio
    if chunk.sequence >= 1 && chunk.sequence % 2 == 1
      # Include up to 30 seconds of context
      start_seq = [ 0, chunk.sequence - 29 ].max
      ProcessAudioJob.perform_later(@session_id, start_seq, chunk.sequence, "rolling")
    end

    # Run BS detection every 3 seconds on the full accumulated transcript
    if chunk.sequence >= 2 && (chunk.sequence + 1) % 3 == 0
      DetectBullshitJob.perform_later(@session_id)
    end
  end

  private

  def next_sequence_number
    last_chunk = AudioChunk.for_session(@session_id).maximum(:sequence) || -1
    last_chunk + 1
  end

  def process_remaining_chunks
    remaining_chunks = AudioChunk.for_session(@session_id)
    return if remaining_chunks.empty?

    # Process any final chunks
    last_sequence = remaining_chunks.maximum(:sequence)
    if last_sequence >= 0
      start_seq = [ 0, last_sequence - 29 ].max
      ProcessAudioJob.perform_later(@session_id, start_seq, last_sequence, "final")
    end

    # Clean up chunks after a delay
    AudioChunk.for_session(@session_id).destroy_all
  end
end
