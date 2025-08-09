namespace :roast do
  desc "Debug greeting workflow execution"
  task debug_greeting: :environment do
    puts "\n=== Debugging Greeting Workflow ==="
    puts "Rails environment: #{Rails.env}"
    puts "Raix client configured: #{Raix.configuration.openai_client.present?}"
    puts "API key present: #{Rails.configuration.x.openai.api_key.present?}"
    puts "API key first 20 chars: #{Rails.configuration.x.openai.api_key&.first(20)}..."

    puts "\n--- Executing workflow ---"

    Dir.mktmpdir("debug_greeting") do |temp_dir|
      # Copy workflow files
      workflow_path = Rails.root.join("app/workflows/greeting")
      FileUtils.cp_r(workflow_path.to_s + "/.", temp_dir)

      # List files
      puts "\nWorkflow files:"
      Dir.glob("#{temp_dir}/**/*").each do |file|
        puts "  #{file}" if File.file?(file)
      end

      # Create output file
      output_file = Tempfile.new([ "greeting_output", ".txt" ], temp_dir)

      # Parse and execute workflow
      workflow_yml_path = File.join(temp_dir, "workflow.yml")
      parser = Roast::Workflow::ConfigurationParser.new(
        workflow_yml_path,
        [],
        { output: output_file.path }
      )

      puts "\nExecuting workflow..."
      parser.begin!

      # Read result
      result = File.read(output_file.path)
      puts "\n--- Result ---"
      puts result
      puts "--- End Result ---"
    end
  rescue => e
    puts "\nError: #{e.class}: #{e.message}"
    puts e.backtrace.first(10).join("\n")
  end

  desc "Debug example workflow execution"
  task debug_example: :environment do
    puts "\n=== Debugging Example Workflow ==="

    input = ENV["INPUT"] || "This is a test input for debugging"
    puts "Input: #{input}"

    puts "\n--- Executing workflow ---"

    Dir.mktmpdir("debug_example") do |temp_dir|
      # Copy workflow files
      workflow_path = Rails.root.join("app/workflows/example_workflow")
      FileUtils.cp_r(workflow_path.to_s + "/.", temp_dir)

      # Update input file
      File.write(File.join(temp_dir, "input.md"), input)

      # Create output file
      output_file = Tempfile.new([ "workflow_output", ".txt" ], temp_dir)

      # Parse and execute workflow
      workflow_yml_path = File.join(temp_dir, "workflow.yml")
      parser = Roast::Workflow::ConfigurationParser.new(
        workflow_yml_path,
        [],
        { output: output_file.path }
      )

      puts "\nExecuting workflow..."
      parser.begin!

      # Read result
      result = File.read(output_file.path)
      puts "\n--- Raw Result ---"
      puts result
      puts "--- End Raw Result ---"

      # Try to parse JSON
      puts "\n--- Parsed Result ---"
      json_match = result.match(/```json\n(.*?)\n```/m)
      json_content = json_match ? json_match[1] : result
      parsed = JSON.parse(json_content)
      puts JSON.pretty_generate(parsed)
    end
  rescue => e
    puts "\nError: #{e.class}: #{e.message}"
    puts e.backtrace.first(10).join("\n")
  end

  desc "Debug Raix configuration"
  task debug_raix: :environment do
    puts "\n=== Raix Configuration Debug ==="
    puts "Raix client class: #{Raix.configuration.openai_client.class}"
    puts "Client responds to chat: #{Raix.configuration.openai_client.respond_to?(:chat)}"

    puts "\n--- Testing direct API call ---"
    client = Raix.configuration.openai_client
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [ { role: "user", content: "Say 'test successful'" } ],
        temperature: 0.7
      }
    )

    puts "Response: #{response.dig("choices", 0, "message", "content")}"
  rescue => e
    puts "\nError: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
end
