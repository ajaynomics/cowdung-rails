namespace :bullshit do
  desc "Test bullshit detection with sample text"
  task test: :environment do
    puts "Testing bullshit detection with Raix integration..."
    puts "=" * 60

    # Test samples with varying levels of BS
    test_samples = [
      {
        name: "Corporate Jargon",
        text: "We need to leverage our synergies to create a paradigm shift in how we actualize our core competencies. By thinking outside the box and taking a 30,000 foot view, we can move the needle on our key performance indicators while ensuring we have all our ducks in a row."
      },
      {
        name: "Evasive Answer",
        text: "Well, that's a great question and I'm glad you asked it. You know, there are many factors to consider here, and we're looking at all the options. What's important is that we remain focused on the bigger picture and continue to evaluate the situation as it evolves."
      },
      {
        name: "Clear Statement",
        text: "The project will cost $50,000 and take 3 months to complete. We'll need a team of 4 developers. The main risks are the integration with the legacy system and the tight deadline. We'll mitigate these by starting with the integration work first."
      },
      {
        name: "Obvious Exaggeration",
        text: "This is literally the best product ever created in the history of mankind. It will revolutionize everything and make you 1000% more productive. Everyone who uses it becomes instantly successful and wealthy. It's basically magic."
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
