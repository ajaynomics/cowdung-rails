class AudioChunk < ApplicationRecord
  validates :session_id, presence: true
  validates :data, presence: true
  validates :sequence, presence: true, uniqueness: { scope: :session_id }

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :in_sequence, -> { order(:sequence) }

  # Convert base64 PCM data to raw bytes
  def pcm_data
    Base64.decode64(data)
  end
end
