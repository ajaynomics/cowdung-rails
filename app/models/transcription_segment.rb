class TranscriptionSegment < ApplicationRecord
  validates :session_id, presence: true
  validates :text, presence: true
  validates :start_sequence, presence: true
  validates :end_sequence, presence: true

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :in_order, -> { order(:start_sequence) }
end
