class TranscriptionSegment < ApplicationRecord
  validates :session_id, presence: true
  validates :text, presence: true
  validates :start_sequence, presence: true
  validates :end_sequence, presence: true

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :in_order, -> { order(:start_sequence) }

  # Transcribe audio chunks using OpenAI Whisper
  def self.transcribe_chunks(audio_chunks)
    return { success?: false, error: "No audio chunks provided" } if audio_chunks.empty?

    # Create WAV file from PCM chunks
    temp_file = create_wav_from_chunks(audio_chunks)

    Rails.logger.info "Sending file to Whisper: #{temp_file.path}, size: #{File.size(temp_file.path)} bytes"

    client = Raix.configuration.openai_client
    response = client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: temp_file,
        language: "en"
      }
    )

    { success?: true, text: response["text"] }
  rescue => e
    Rails.logger.error "Whisper transcription error: #{e.message}"
    { success?: false, error: e.message }
  ensure
    temp_file&.close
    temp_file&.unlink
  end

  private_class_method def self.create_wav_from_chunks(audio_chunks)
    output_file = Tempfile.new([ "audio", ".wav" ])
    output_file.binmode

    # Get audio parameters from first chunk
    sample_rate = audio_chunks.first.sample_rate || 44100
    bits_per_sample = 16
    channels = 1

    # Combine all PCM data
    pcm_data = audio_chunks.map(&:pcm_data).join
    data_size = pcm_data.bytesize

    # Write WAV header
    output_file.write("RIFF")
    output_file.write([ data_size + 36 ].pack("V")) # File size - 8
    output_file.write("WAVE")

    # Format chunk
    output_file.write("fmt ")
    output_file.write([ 16 ].pack("V")) # Format chunk size
    output_file.write([ 1 ].pack("v"))  # PCM format
    output_file.write([ channels ].pack("v"))
    output_file.write([ sample_rate ].pack("V"))
    output_file.write([ sample_rate * channels * bits_per_sample / 8 ].pack("V")) # Byte rate
    output_file.write([ channels * bits_per_sample / 8 ].pack("v")) # Block align
    output_file.write([ bits_per_sample ].pack("v"))

    # Data chunk
    output_file.write("data")
    output_file.write([ data_size ].pack("V"))
    output_file.write(pcm_data)

    output_file.rewind
    output_file
  end
end
