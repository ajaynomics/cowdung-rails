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

          # Filter out repetitions from hallucination
          new_text = filter_repetitions(new_text, session_transcript.current_text)
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

  private

  def filter_repetitions(new_text, existing_text)
    return new_text if existing_text.blank?

    # Get last few words from existing text
    existing_words = existing_text.split.last(10)
    new_words = new_text.split

    # Check if new text starts with repetition of last words
    overlap_count = 0
    existing_words.each_with_index do |word, i|
      break if i >= new_words.length
      if word.downcase == new_words[i].downcase
        overlap_count += 1
      else
        break
      end
    end

    # Remove overlapping words from start of new text
    if overlap_count > 0
      new_words = new_words[overlap_count..]
    end

    # Also check for simple repetitions like "you you you"
    filtered_words = []
    last_word = nil
    repeat_count = 0

    new_words.each do |word|
      if word.downcase == last_word&.downcase
        repeat_count += 1
        # Allow max 2 repetitions of same word
        if repeat_count <= 1
          filtered_words << word
        end
      else
        filtered_words << word
        last_word = word
        repeat_count = 0
      end
    end

    filtered_words.join(" ")
  end
end
