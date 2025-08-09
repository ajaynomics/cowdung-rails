class DetectorChannel < ApplicationCable::Channel
  def subscribed
    session_id = params[:session_id]
    stream_from "detector_#{session_id}"
    Rails.logger.info "✅ DetectorChannel subscribed: #{session_id}"
  end

  def unsubscribed
    Rails.logger.info "❌ DetectorChannel unsubscribed: #{params[:session_id]}"
  end

  def receive_audio(data)
    Rails.logger.info "🎤 Audio chunk received - session: #{params[:session_id]}, size: #{data['audio_chunk']&.length || 0}"
  end
end
