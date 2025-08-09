class DetectBullshitJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    Rails.logger.info "Running bullshit detection for session #{session_id}"

    # Don't run BS detection if there's no recent audio activity
    last_chunk = AudioChunk.for_session(session_id).maximum(:created_at)
    if last_chunk && last_chunk < 10.seconds.ago
      Rails.logger.info "Skipping BS detection - no recent audio activity"
      return
    end

    # Get the current transcript
    session_transcript = SessionTranscript.find_by(session_id: session_id)
    return unless session_transcript&.current_text.present?

    # Skip if text is too short
    return if session_transcript.current_text.length < 50

    # Perform the analysis with deduplication
    analysis = BullshitAnalysis.analyze_transcript(session_id, session_transcript.current_text)

    # Skip if no analysis returned
    return unless analysis

    # If bullshit was detected AND it's not a duplicate, broadcast it
    if analysis.detected? && !analysis.is_duplicate
      ActionCable.server.broadcast(
        "detector_#{session_id}",
        {
          type: "bullshit_detected",
          detected: true,
          confidence: analysis.confidence,
          bs_type: analysis.bs_type,
          explanation: analysis.explanation,
          quote: analysis.quote,
          timestamp: Time.current
        }
      )

      Rails.logger.info "🚨 Bullshit detected in session #{session_id}: #{analysis.explanation}"
    elsif analysis.detected? && analysis.is_duplicate
      Rails.logger.info "📋 Duplicate BS detected in session #{session_id}: #{analysis.quote}"
    end
  rescue => e
    Rails.logger.error "Bullshit detection failed for session #{session_id}: #{e.message}"
  end
end
