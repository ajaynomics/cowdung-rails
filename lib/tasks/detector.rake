namespace :detector do
  desc "Test WhisperService with a sample audio file"
  task test_whisper: :environment do
    puts "Testing WhisperService..."

    # Create a real audio file using system TTS
    temp_audio = Tempfile.new([ "test_audio", ".aiff" ])
    temp_webm = Tempfile.new([ "test_audio", ".webm" ])

    begin
      # Use macOS say command to generate audio
      test_text = "Hello, this is a test of the bullshit detector transcription service."
      puts "Generating audio with text: #{test_text}"
      system("say -o #{temp_audio.path} '#{test_text}'")

      # Convert to WebM format
      puts "Converting to WebM..."
      system("ffmpeg -i #{temp_audio.path} -c:a libopus -b:a 32k #{temp_webm.path} -y")

      # Read the WebM file and create chunk
      webm_data = File.read(temp_webm.path, mode: "rb")
      chunk = AudioChunk.new(
        session_id: "test-rake-#{Time.current.to_i}",
        data: Base64.encode64(webm_data),
        sequence: 0
      )

      puts "Created audio chunk with #{webm_data.size} bytes"

      service = WhisperService.new
      result = service.transcribe_chunks([ chunk ])

      if result.success?
        puts "✅ Transcription successful!"
        puts "Text: #{result.text}"
        puts "Expected: #{test_text}"
      else
        puts "❌ Transcription failed!"
        puts "Error: #{result.error}"
      end
    ensure
      temp_audio.close
      temp_audio.unlink
      temp_webm.close
      temp_webm.unlink
    end
  end

  desc "Test full audio flow: save chunks, process, and transcribe"
  task test_full_flow: :environment do
    puts "Testing full audio flow..."
    session_id = "test-flow-#{Time.current.to_i}"

    # Create real audio chunks
    puts "1. Creating real audio chunks..."
    test_phrases = [
      "This is chunk number one",
      "Here comes chunk two",
      "And this is chunk three",
      "Number four checking in",
      "Finally chunk five"
    ]

    test_phrases.each_with_index do |phrase, i|
      temp_audio = Tempfile.new([ "chunk_#{i}", ".aiff" ])
      temp_webm = Tempfile.new([ "chunk_#{i}", ".webm" ])

      begin
        system("say -o #{temp_audio.path} '#{phrase}'", out: File::NULL, err: File::NULL)
        system("ffmpeg -i #{temp_audio.path} -c:a libopus -b:a 32k #{temp_webm.path} -y",
               out: File::NULL, err: File::NULL)

        webm_data = File.read(temp_webm.path, mode: "rb")
        AudioChunk.create!(
          session_id: session_id,
          data: Base64.encode64(webm_data),
          sequence: i
        )
      ensure
        temp_audio.close && temp_audio.unlink
        temp_webm.close && temp_webm.unlink
      end
    end

    puts "   Created #{AudioChunk.where(session_id: session_id).count} chunks"

    # Process the chunks
    puts "2. Processing chunks with job..."
    ProcessAudioJob.perform_now(session_id, 0, 4)

    # Check results
    segment = TranscriptionSegment.where(session_id: session_id).first
    if segment
      puts "✅ Transcription segment created!"
      puts "   Text: #{segment.text}"
      puts "   Duration: #{segment.duration} seconds"
    else
      puts "❌ No transcription segment created"
    end

    # Check cleanup
    remaining_chunks = AudioChunk.where(session_id: session_id).count
    puts "3. Cleanup: #{remaining_chunks} chunks remaining (should be 0)"
  end

  desc "Test with real audio recording simulation"
  task test_recording: :environment do
    puts "Simulating real audio recording..."
    session_id = "recording-#{Time.current.to_i}"

    # Simulate 35 chunks (35 seconds of audio)
    puts "Creating 35 audio chunks..."
    35.times do |i|
      AudioChunk.create!(
        session_id: session_id,
        data: Base64.encode64("audio chunk #{i}"),
        sequence: i
      )

      # Check if we should process
      if i > 0 && i % 30 == 0
        puts "  Triggering processing at chunk #{i}..."
        ProcessAudioJob.perform_now(session_id, i - 29, i)
      end
    end

    # Process remaining chunks
    unprocessed = AudioChunk.where(session_id: session_id, processed: false)
    if unprocessed.any?
      puts "Processing final #{unprocessed.count} chunks..."
      first = unprocessed.minimum(:sequence)
      last = unprocessed.maximum(:sequence)
      ProcessAudioJob.perform_now(session_id, first, last)
    end

    # Show all transcriptions
    segments = TranscriptionSegment.where(session_id: session_id).order(:start_sequence)
    puts "\nTranscription segments created: #{segments.count}"
    segments.each do |segment|
      puts "  [#{segment.start_sequence}-#{segment.end_sequence}]: #{segment.text.truncate(50)}"
    end
  end
end
