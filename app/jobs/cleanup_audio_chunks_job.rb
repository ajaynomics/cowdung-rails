class CleanupAudioChunksJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    # Clean up audio chunks for this session
    AudioChunk.for_session(session_id).destroy_all

    Rails.logger.info "Cleaned up audio chunks for session #{session_id}"
  end
end
