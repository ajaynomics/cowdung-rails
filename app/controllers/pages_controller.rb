class PagesController < ApplicationController
  def audio
  end

  def greeting
    # Debug: Check if Raix is configured
    Rails.logger.info "Raix client configured: #{Raix.configuration.openai_client.present?}"

    # Run the greeting workflow synchronously
    Dir.mktmpdir("greeting") do |temp_dir|
      # Copy workflow files to temp directory
      workflow_path = Rails.root.join("app/workflows/greeting")
      FileUtils.cp_r(workflow_path.to_s + "/.", temp_dir)

      # Create output file
      output_file = Tempfile.new([ "greeting_output", ".txt" ], temp_dir)

      # Parse and execute workflow
      workflow_yml_path = File.join(temp_dir, "workflow.yml")
      parser = Roast::Workflow::ConfigurationParser.new(
        workflow_yml_path,
        [],
        { output: output_file.path }
      )
      parser.begin!

      # Read the result
      @greeting_response = File.read(output_file.path)
    end
  rescue StandardError => e
    Rails.logger.error "Full error: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @greeting_response = "Error: #{e.message}"
  end
end
