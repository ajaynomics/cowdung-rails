namespace :detector do
  desc "End-to-end test simulating real browser audio chunks"
  task e2e_test: :environment do
    puts "=== Bullshit Detector End-to-End Test ==="
    puts

    session_id = "e2e-test-#{Time.current.to_i}"

    # Simulate what the browser would send
    puts "1. Simulating browser recording chunks..."

    # Create a longer audio file and split it into 1-second chunks
    full_text = "Let me tell you about our revolutionary new product. " \
                "It uses quantum blockchain AI to synergize your workflow. " \
                "Our patented algorithm leverages machine learning to optimize ROI. " \
                "Studies show a ten thousand percent improvement in productivity. " \
                "This disruptive technology will revolutionize the industry. " \
                "Act now and we'll throw in a free NFT of your digital twin. " \
                "Remember, this is not financial advice, but you'd be crazy not to invest. " \
                "Our team of ninja rockstar developers coded this in just one weekend. " \
                "We're the Uber of productivity tools meets the Netflix of work optimization. " \
                "Sign up today and join the future of work."

    # Generate full audio
    puts "   Generating test audio..."
    full_audio = Tempfile.new([ "full_audio", ".aiff" ])
    full_webm = Tempfile.new([ "full_audio", ".webm" ])

    begin
      # Escape single quotes in the text
      escaped_text = full_text.gsub("'", "\\'")

      puts "   Running text-to-speech..."
      result = system("say -o #{full_audio.path} \"#{escaped_text}\"")
      unless result
        puts "   ❌ Error: Failed to generate audio with 'say' command"
        return
      end

      puts "   Converting to WebM..."
      result = system("ffmpeg -i #{full_audio.path} -c:a libopus -b:a 32k #{full_webm.path} -y",
                     out: File::NULL, err: File::NULL)
      unless result
        puts "   ❌ Error: Failed to convert audio to WebM"
        return
      end

      # For this test, we'll simulate by creating multiple chunks from the same audio
      # In reality, the browser would send individual 1-second chunks
      webm_data = File.read(full_webm.path, mode: "rb")
      puts "   Generated #{webm_data.size} bytes of audio"
      base64_data = Base64.encode64(webm_data)

      if base64_data.empty?
        puts "   ❌ Error: No audio data generated"
        return
      end

      # Simulate 35 chunks (35 seconds of "recording")
      35.times do |i|
        print "."

        # Create chunk (in real app, each would be a separate 1-second recording)
        chunk = AudioChunk.create!(
          session_id: session_id,
          data: base64_data, # Using same data for simulation
          sequence: i
        )

        # Check if we hit 30 chunks
        if i == 29
          puts "\n   30 chunks received - triggering transcription..."
          ProcessAudioJob.perform_now(session_id, 0, 29)
        end
      end

      puts "\n   Recording stopped at chunk 35"

      # Process remaining chunks (simulating user clicking stop)
      unprocessed = AudioChunk.where(session_id: session_id, processed: false)
      if unprocessed.any?
        puts "   Processing final #{unprocessed.count} chunks..."
        first = unprocessed.minimum(:sequence)
        last = unprocessed.maximum(:sequence)
        ProcessAudioJob.perform_now(session_id, first, last)
      end

    ensure
      full_audio.close && full_audio.unlink
      full_webm.close && full_webm.unlink
    end

    puts "\n2. Transcription Results:"
    puts "   " + "="*60

    segments = TranscriptionSegment.where(session_id: session_id).order(:start_sequence)

    if segments.any?
      segments.each do |segment|
        puts "   [Chunks #{segment.start_sequence}-#{segment.end_sequence}]:"
        puts "   #{segment.text}"
        puts
      end

      puts "   Total segments: #{segments.count}"
      puts "   Total text length: #{segments.sum { |s| s.text.length }} characters"
    else
      puts "   ❌ No transcriptions created!"
    end

    puts "\n3. Cleanup verification:"
    remaining = AudioChunk.where(session_id: session_id).count
    puts "   Audio chunks remaining: #{remaining} (should be 0)"

    puts "\n=== Test Complete ==="
  end

  desc "Test WebSocket flow through ActionCable"
  task test_websocket: :environment do
    puts "Testing WebSocket audio flow..."

    # This would require actually connecting via WebSocket
    # For now, we'll simulate the channel behavior
    session_id = "websocket-test-#{Time.current.to_i}"

    # Simulate channel receiving audio
    channel = DetectorChannel.new(nil, { session_id: session_id })

    # Simulate receiving 5 audio chunks
    5.times do |i|
      puts "Sending chunk #{i + 1}..."

      # Create a small test audio
      temp_audio = Tempfile.new([ "ws_chunk_#{i}", ".aiff" ])
      temp_webm = Tempfile.new([ "ws_chunk_#{i}", ".webm" ])

      begin
        system("say -o #{temp_audio.path} 'Chunk #{i + 1}'", out: File::NULL, err: File::NULL)
        system("ffmpeg -i #{temp_audio.path} -c:a libopus -b:a 32k #{temp_webm.path} -y",
               out: File::NULL, err: File::NULL)

        webm_data = File.read(temp_webm.path, mode: "rb")

        # This simulates what the frontend sends
        data = {
          "audio_chunk" => Base64.encode64(webm_data)
        }

        # Can't actually call receive_audio without proper connection setup
        # But we can show what would happen
        puts "   Would send #{webm_data.size} bytes of audio data"

      ensure
        temp_audio.close && temp_audio.unlink
        temp_webm.close && temp_webm.unlink
      end
    end

    puts "\nNote: Full WebSocket testing requires browser connection"
    puts "Run 'bin/dev' and test with the actual UI for complete verification"
  end
end
