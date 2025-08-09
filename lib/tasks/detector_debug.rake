namespace :detector do
  desc "Debug audio chunk processing"
  task debug_chunks: :environment do
    session_id = ENV["SESSION_ID"]

    unless session_id
      puts "Usage: SESSION_ID=xxx bin/rake detector:debug_chunks"
      puts "\nRecent sessions:"
      AudioChunk.select(:session_id).distinct.order(created_at: :desc).limit(5).each do |chunk|
        count = AudioChunk.where(session_id: chunk.session_id).count
        puts "  #{chunk.session_id} (#{count} chunks)"
      end
      return
    end

    chunks = AudioChunk.where(session_id: session_id).order(:sequence)
    puts "Found #{chunks.count} chunks for session #{session_id}"

    if chunks.any?
      puts "\nChunk details:"
      chunks.each do |chunk|
        decoded = Base64.decode64(chunk.data)
        puts "  Chunk #{chunk.sequence}: #{decoded.size} bytes, processed: #{chunk.processed}"

        # Check if it's valid WebM
        if decoded[0..3] == "\x1A\x45\xDF\xA3"
          puts "    ✓ Valid WebM header"
        else
          puts "    ✗ Invalid WebM header: #{decoded[0..3].bytes.map { |b| sprintf("%02X", b) }.join(' ')}"
        end
      end

      # Try to save first chunk to file for inspection
      if chunks.first
        test_file = "/tmp/test_chunk.webm"
        File.open(test_file, "wb") do |f|
          f.write(Base64.decode64(chunks.first.data))
        end
        puts "\nFirst chunk saved to #{test_file}"
        puts "You can test with: ffprobe #{test_file}"
      end
    end
  end

  desc "Test transcription with saved chunks"
  task test_saved_chunks: :environment do
    session_id = ENV["SESSION_ID"]
    start_seq = ENV["START"]&.to_i || 0
    end_seq = ENV["END"]&.to_i || 29

    unless session_id
      puts "Usage: SESSION_ID=xxx START=0 END=29 bin/rake detector:test_saved_chunks"
      return
    end

    chunks = AudioChunk.where(session_id: session_id, sequence: start_seq..end_seq).order(:sequence)
    puts "Testing with #{chunks.count} chunks (#{start_seq}..#{end_seq})"

    if chunks.any?
      service = WhisperService.new
      result = service.transcribe_chunks(chunks)

      if result.success?
        puts "✅ Transcription successful!"
        puts "Text: #{result.text}"
      else
        puts "❌ Transcription failed!"
        puts "Error: #{result.error}"
      end
    else
      puts "No chunks found!"
    end
  end
end
