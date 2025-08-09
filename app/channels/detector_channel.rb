class DetectorChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]
    stream_from "detector_#{@session_id}"
    Rails.logger.info "✅ DetectorChannel subscribed: #{@session_id}"
  end

  def unsubscribed
    Rails.logger.info "❌ DetectorChannel unsubscribed: #{@session_id}"
    # Process any remaining chunks when user stops recording
    process_remaining_chunks
  end

  def receive_audio(data)
    audio_data = data["audio_chunk"]
    Rails.logger.info "🎤 Audio chunk received - session: #{@session_id}, size: #{audio_data&.length || 0}"

    # Validate we have audio data
    if audio_data.blank?
      Rails.logger.error "No audio data in chunk!"
      return
    end

    # Save the audio chunk
    sequence = next_sequence_number
    chunk = AudioChunk.create!(
      session_id: @session_id,
      data: audio_data,
      sequence: sequence
    )

    Rails.logger.info "Saved chunk #{sequence} for session #{@session_id}"

    # Accumulate chunks and process every 30 seconds (6 chunks)
    # This gives us meaningful audio for transcription
    if (sequence + 1) % 6 == 0
      start_seq = sequence - 5
      Rails.logger.info "Processing 30-second batch: chunks #{start_seq}-#{sequence}"
      ProcessAudioJob.perform_later(@session_id, start_seq, sequence)
    end
  end

  private

  def next_sequence_number
    last_chunk = AudioChunk.for_session(@session_id).maximum(:sequence) || -1
    last_chunk + 1
  end

  def process_remaining_chunks
    unprocessed_chunks = AudioChunk.for_session(@session_id).unprocessed
    return if unprocessed_chunks.empty?

    first_sequence = unprocessed_chunks.minimum(:sequence)
    last_sequence = unprocessed_chunks.maximum(:sequence)

    # Process remaining chunks even if less than 30
    ProcessAudioJob.perform_later(@session_id, first_sequence, last_sequence)
  end
end
