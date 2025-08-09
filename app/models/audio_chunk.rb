class AudioChunk < ApplicationRecord
  validates :session_id, presence: true
  validates :data, presence: true
  validates :sequence, presence: true, uniqueness: { scope: :session_id }

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :unprocessed, -> { where(processed: false) }
  scope :in_sequence, -> { order(:sequence) }

  def self.ready_for_transcription(session_id)
    for_session(session_id)
      .unprocessed
      .in_sequence
      .limit(30) # 30 seconds worth
  end

  # Check if this chunk starts a new recording (has WebM header)
  def has_webm_header?
    decoded = Base64.decode64(data)
    return false if decoded.length < 4
    header_bytes = decoded[0..3].unpack("C*")
    header_bytes == [ 0x1A, 0x45, 0xDF, 0xA3 ]
  end
end
