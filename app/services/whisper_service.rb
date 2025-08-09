require "base64"
require "tempfile"
require "open3"

class WhisperService
  Result = Struct.new(:success?, :text, :error, keyword_init: true)

  def initialize
    @client = OpenAI::Client.new(
      access_token: Rails.configuration.x.openai.api_key
    )
  end

  def transcribe_chunks(audio_chunks)
    return Result.new(success?: false, error: "No audio chunks provided") if audio_chunks.empty?

    # Check format of chunks
    format = audio_chunks.first.format || "webm"

    temp_file = if format == "pcm16"
                  create_wav_from_pcm(audio_chunks)
    else
                  create_webm_from_segments(audio_chunks)
    end

    Rails.logger.info "Sending file to Whisper: #{temp_file.path}, size: #{File.size(temp_file.path)} bytes"

    response = @client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: temp_file,
        language: "en"
      }
    )

    Result.new(success?: true, text: response["text"])
  rescue => e
    Rails.logger.error "Whisper transcription error: #{e.message}"
    Result.new(success?: false, error: e.message)
  ensure
    temp_file&.close
    temp_file&.unlink
  end

  private

  def create_wav_from_pcm(audio_chunks)
    output_file = Tempfile.new([ "audio", ".wav" ])
    output_file.binmode

    # Get audio parameters from first chunk
    sample_rate = audio_chunks.first.sample_rate || 44100
    bits_per_sample = 16
    channels = 1

    # Combine all PCM data
    pcm_data = audio_chunks.map { |chunk| Base64.decode64(chunk.data) }.join
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

  def create_webm_from_segments(audio_chunks)
    # Browser MediaRecorder sends WebM segments:
    # - First chunk: Has EBML header + segment data
    # - Later chunks: Just segment data (no headers)
    # We need to reconstruct a complete WebM file

    output_file = Tempfile.new([ "complete_audio", ".webm" ])
    output_file.binmode

    begin
      # Check if first chunk has valid WebM header
      first_chunk_data = Base64.decode64(audio_chunks.first.data)
      header_bytes = first_chunk_data[0..3].unpack("C*")

      if header_bytes == [ 0x1A, 0x45, 0xDF, 0xA3 ] # Valid EBML header
        Rails.logger.info "First chunk has valid WebM header"
        # Simple concatenation might work
        audio_chunks.each do |chunk|
          output_file.write(Base64.decode64(chunk.data))
        end
      else
        Rails.logger.info "Using ffmpeg to reconstruct WebM from segments"
        # Use ffmpeg to create proper WebM from segments

        # Write all data to a single file first
        concat_file = Tempfile.new([ "concat", ".webm" ])
        concat_file.binmode
        audio_chunks.each do |chunk|
          concat_file.write(Base64.decode64(chunk.data))
        end
        concat_file.close

        # Use ffmpeg to create a proper WebM file
        cmd = "ffmpeg -i #{concat_file.path} -c:a copy #{output_file.path} -y 2>&1"
        Rails.logger.info "Running: #{cmd}"

        output = `#{cmd}`
        success = $?.success?

        unless success
          Rails.logger.error "ffmpeg failed: #{output}"
          # Last resort: try with re-encoding
          cmd = "ffmpeg -i #{concat_file.path} -c:a libopus -b:a 32k #{output_file.path} -y 2>&1"
          output = `#{cmd}`
          success = $?.success?

          unless success
            Rails.logger.error "ffmpeg re-encode failed: #{output}"
            # Ultimate fallback: use raw concatenation
            output_file.rewind
            audio_chunks.each do |chunk|
              output_file.write(Base64.decode64(chunk.data))
            end
          end
        end

        concat_file.unlink rescue nil
      end

      output_file.rewind
      output_file
    rescue => e
      Rails.logger.error "Error creating WebM: #{e.message}"
      output_file.rewind
      output_file
    end
  end
end
