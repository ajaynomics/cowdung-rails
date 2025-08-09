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

    # WebM chunks from browser are segments, not complete files
    # We need to create a proper WebM container
    temp_file = create_webm_from_segments(audio_chunks)

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

  def create_webm_from_segments(audio_chunks)
    # Since browser sends 5-second chunks that are WebM segments,
    # we need to create a proper WebM container with header

    # For now, if we only have one chunk, just use it directly
    if audio_chunks.size == 1
      temp_file = Tempfile.new([ "audio", ".webm" ])
      temp_file.binmode
      temp_file.write(Base64.decode64(audio_chunks.first.data))
      temp_file.rewind
      return temp_file
    end

    # For multiple chunks, we need to use ffmpeg to create a proper container
    # Each chunk is a WebM segment, not a complete file
    output_file = Tempfile.new([ "complete_audio", ".webm" ])
    chunk_files = []

    begin
      # Write each segment to a temporary file
      audio_chunks.each_with_index do |chunk, index|
        chunk_file = Tempfile.new([ "segment_#{index}", ".webm" ])
        chunk_file.binmode
        chunk_file.write(Base64.decode64(chunk.data))
        chunk_file.close
        chunk_files << chunk_file
      end

      # Use ffmpeg to create a proper WebM file from segments
      # We'll use the concat protocol which works better for segments
      inputs = chunk_files.map { |f| "-i #{f.path}" }.join(" ")
      filter_complex = chunk_files.each_index.map { |i| "[#{i}:a]" }.join("") + "concat=n=#{chunk_files.size}:v=0:a=1[out]"

      cmd = "ffmpeg #{inputs} -filter_complex \"#{filter_complex}\" -map \"[out]\" -c:a libopus -b:a 32k #{output_file.path} -y 2>&1"
      Rails.logger.info "Creating WebM container with command: #{cmd}"

      output = `#{cmd}`
      success = $?.success?

      unless success
        Rails.logger.error "Failed to create WebM container: #{output}"
        # Fallback: just use the first chunk
        output_file.binmode
        output_file.write(Base64.decode64(audio_chunks.first.data))
        Rails.logger.warn "Using first chunk as fallback"
      else
        Rails.logger.info "Successfully created WebM container"
      end

      output_file.rewind
      output_file
    ensure
      # Clean up segment files
      chunk_files.each { |f| f.unlink rescue nil }
    end
  end
end
