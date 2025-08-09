class AudioTranscriptionChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]
    stream_from "audio_transcription_#{@session_id}"
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

    # Process every 10 seconds (10 chunks)
    if (chunk.sequence + 1) % 10 == 0
      start_seq = chunk.sequence - 9
      ProcessAudioJob.perform_later(@session_id, start_seq, chunk.sequence)
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

    # Get the highest sequence number
    last_sequence = remaining_chunks.maximum(:sequence)

    # Find the last batch that was processed (multiples of 10)
    last_processed_batch = (last_sequence / 10) * 10 - 1

    # If we have chunks after the last processed batch, process them
    if last_sequence > last_processed_batch
      first_sequence = last_processed_batch + 1
      ProcessAudioJob.perform_later(@session_id, first_sequence, last_sequence)
    end
  end
end
