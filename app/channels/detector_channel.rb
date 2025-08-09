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

    # Process every 3 seconds with sliding window
    # First window at chunk 2 (sequences 0-2)
    # Then slide by 2: chunks 4 (2-4), 6 (4-6), etc.
    if chunk.sequence == 2 || (chunk.sequence > 2 && (chunk.sequence - 2) % 2 == 0)
      # Calculate window with 1-second overlap
      end_seq = chunk.sequence
      start_seq = [ 0, end_seq - 2 ].max

      ProcessAudioJob.perform_later(@session_id, start_seq, end_seq)
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

    # Find the last window that would have been processed
    # Windows are at sequences 2, 4, 6, 8, etc.
    if last_sequence < 2
      # Not enough chunks for even one window
      return
    end

    # Find the last processed window end
    last_processed_end = if last_sequence == 2
      -1 # Nothing processed yet
    else
      # Find the last even sequence that would trigger processing
      ((last_sequence - 2) / 2) * 2 + 2 - 1
    end

    # If we have unprocessed chunks, process the final window
    if last_sequence > last_processed_end
      start_seq = [ 0, last_sequence - 2 ].max
      Rails.logger.info "Processing remaining chunks for session #{@session_id}, sequences #{start_seq}-#{last_sequence}"
      ProcessAudioJob.perform_later(@session_id, start_seq, last_sequence)
    end
  end
end
