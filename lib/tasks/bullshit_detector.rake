namespace :bullshit do
  desc "Test bullshit detection with sample text"
  task test: :environment do
    puts "Testing bullshit detection with Raix integration..."
    puts "=" * 60

    # Test samples with varying levels of BS
    test_samples = [
      {
        name: "Corporate Jargon (Should Ignore)",
        text: "We need to leverage our synergies to create a paradigm shift in how we actualize our core competencies. By thinking outside the box and taking a 30,000 foot view, we can move the needle on our key performance indicators."
      },
      {
        name: "Factual Error",
        text: "The sky is green and grass is blue. Also, water freezes at 100 degrees Celsius and the sun revolves around the earth. These are scientific facts that everyone should know."
      },
      {
        name: "Fair Opinion",
        text: "I think the new tax policy is terrible and will hurt small businesses. In my opinion, we should reduce regulations and let the free market decide. This is the best pizza I've ever had!"
      },
      {
        name: "Dangerous Misinformation",
        text: "Drinking bleach cures all diseases. The government is hiding this from you. I've been doing it for years and I'm healthier than ever. You should stop taking all medications and just drink a cup of bleach daily."
      },
      {
        name: "Impossible Claim",
        text: "I can fly without any equipment. Yesterday I flew to the moon and back in 30 minutes. I also invented time travel last week and I'm actually 500 years old."
      },
      {
        name: "Obvious Scam",
        text: "Send me $1000 and I'll send you back $10,000 tomorrow. This is a guaranteed investment with zero risk. I'm a Nigerian prince and I need your help to access my fortune."
      }
    ]

    test_samples.each do |sample|
      puts "\nTesting: #{sample[:name]}"
      puts "-" * 40
      puts "Text: #{sample[:text]}"
      puts "\nAnalyzing..."

      begin
        # Create a temporary session for testing
        session_id = "test-#{Time.current.to_i}"

        # Run the analysis
        analysis = BullshitAnalysis.analyze_transcript(session_id, sample[:text])

        if analysis
          puts "\nResult:"
          puts "  Detected: #{analysis.detected? ? 'YES' : 'NO'}"
          if analysis.detected?
            puts "  Type: #{analysis.bs_type}"
            puts "  Confidence: #{(analysis.confidence * 100).round}%"
            puts "  Explanation: #{analysis.explanation}"
            puts "  Quote: #{analysis.quote}" if analysis.quote
          end
        else
          puts "\nError: Analysis returned nil"
        end

      rescue => e
        puts "\nError: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end

      puts "\n" + "=" * 60
    end

    puts "\nTest complete!"
  end

  desc "Test with custom text"
  task :custom, [ :text ] => :environment do |t, args|
    text = args[:text] || ENV["TEXT"]

    if text.blank?
      puts "Please provide text to analyze:"
      puts "  rake bullshit:custom[\"Your text here\"]"
      puts "  or"
      puts "  TEXT=\"Your text here\" rake bullshit:custom"
      exit
    end

    puts "Analyzing custom text..."
    puts "=" * 60
    puts "Text: #{text}"
    puts "\nAnalyzing..."

    begin
      session_id = "custom-#{Time.current.to_i}"
      analysis = BullshitAnalysis.analyze_transcript(session_id, text)

      if analysis
        puts "\nResult:"
        puts "  Detected: #{analysis.detected? ? 'YES' : 'NO'}"
        if analysis.detected?
          puts "  Type: #{analysis.bs_type}"
          puts "  Confidence: #{(analysis.confidence * 100).round}%"
          puts "  Explanation: #{analysis.explanation}"
          puts "  Quote: #{analysis.quote}" if analysis.quote
        end
      else
        puts "\nError: Analysis returned nil"
      end

    rescue => e
      puts "\nError: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Test deduplication logic"
  task dedup_test: :environment do
    puts "Testing deduplication logic..."
    puts "=" * 60

    session_id = "dedup-test-#{Time.current.to_i}"

    # First detection: factual error
    text1 = "The sky is green and grass is blue"
    analysis1 = BullshitAnalysis.analyze_transcript(session_id, text1)

    puts "First detection:"
    puts "  Detected: #{analysis1.detected?}"
    puts "  Is duplicate: #{analysis1.is_duplicate}"
    puts "  Quote: #{analysis1.quote}" if analysis1.detected?

    # Try to detect the same BS again (should be marked as duplicate)
    text2 = "As I was saying, the sky is green and water flows upward"
    analysis2 = BullshitAnalysis.analyze_transcript(session_id, text2)

    puts "\nSecond analysis (same BS):"
    puts "  Detected: #{analysis2.detected?}"
    puts "  Is duplicate: #{analysis2.is_duplicate}"
    puts "  Quote: #{analysis2.quote}" if analysis2.detected?

    # Try different BS (should be detected as new)
    text3 = "I can fly without equipment and I'm 500 years old"
    analysis3 = BullshitAnalysis.analyze_transcript(session_id, text3)

    puts "\nThird analysis (different BS):"
    puts "  Detected: #{analysis3.detected?}"
    puts "  Is duplicate: #{analysis3.is_duplicate}"
    puts "  Quote: #{analysis3.quote}" if analysis3.detected?

    # Check what would be shown to user (non-duplicate detections only)
    unique_detections = BullshitAnalysis.for_session(session_id).detected.not_duplicate

    puts "\nUnique BS detections that would trigger pop-ups: #{unique_detections.count}"
    unique_detections.each do |d|
      puts "  - #{d.bs_type}: #{d.quote}"
    end

    # Cleanup
    BullshitAnalysis.for_session(session_id).destroy_all
  end

  desc "Test the full job flow"
  task job_test: :environment do
    puts "Testing full job flow..."
    puts "=" * 60

    # Create test data
    session_id = "job-test-#{Time.current.to_i}"

    # Create a session transcript
    session_transcript = SessionTranscript.create!(
      session_id: session_id,
      current_text: "We're going to disrupt the industry with our groundbreaking blockchain AI solution that leverages quantum computing to deliver unprecedented value propositions. This revolutionary platform will completely transform how businesses operate and guarantee 500% ROI within the first month."
    )

    puts "Created test session: #{session_id}"
    puts "Transcript: #{session_transcript.current_text}"
    puts "\nRunning DetectBullshitJob..."

    # Run the job synchronously
    DetectBullshitJob.perform_now(session_id)

    # Check results
    analysis = BullshitAnalysis.for_session(session_id).first

    if analysis
      puts "\nJob completed successfully!"
      puts "Result:"
      puts "  Detected: #{analysis.detected? ? 'YES' : 'NO'}"
      if analysis.detected?
        puts "  Type: #{analysis.bs_type}"
        puts "  Confidence: #{(analysis.confidence * 100).round}%"
        puts "  Explanation: #{analysis.explanation}"
        puts "  Quote: #{analysis.quote}" if analysis.quote
      end
    else
      puts "\nNo analysis created - check logs for errors"
    end

    # Cleanup
    session_transcript.destroy
    BullshitAnalysis.for_session(session_id).destroy_all

    puts "\nTest cleanup complete!"
  end
end
