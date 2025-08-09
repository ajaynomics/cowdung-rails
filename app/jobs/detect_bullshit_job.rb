class DetectBullshitJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    Rails.logger.info "Running bullshit detection for session #{session_id}"

    # Get the current transcript
    session_transcript = SessionTranscript.find_by(session_id: session_id)
    return unless session_transcript&.current_text.present?

    # Skip if text is too short or hasn't changed much
    return if session_transcript.current_text.length < 50

    # Perform the analysis
    analysis = BullshitAnalysis.analyze_transcript(session_id, session_transcript.current_text)

    return unless analysis

    # If bullshit was detected, broadcast it
    if analysis.detected?
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
    else
      # Optionally broadcast when no BS is detected (for UI updates)
      ActionCable.server.broadcast(
        "detector_#{session_id}",
        {
          type: "bullshit_detected",
          detected: false,
          timestamp: Time.current
        }
      )
    end
  rescue => e
    Rails.logger.error "Bullshit detection failed for session #{session_id}: #{e.message}"
  end
end
