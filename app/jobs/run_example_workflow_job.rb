class RunExampleWorkflowJob < ApplicationJob
  queue_as :default

  def perform(input_text)
    # Create a temporary directory for this workflow run
    Dir.mktmpdir("example_workflow") do |temp_dir|
      # Copy workflow files to temp directory
      workflow_path = Rails.root.join("app/workflows/example_workflow")
      FileUtils.cp_r(workflow_path.to_s + "/.", temp_dir)

      # Update input file with provided text
      File.write(File.join(temp_dir, "input.md"), input_text)

      # Create output file
      output_file = Tempfile.new([ "workflow_output", ".txt" ], temp_dir)

      # Parse and execute workflow
      workflow_yml_path = File.join(temp_dir, "workflow.yml")
      parser = Roast::Workflow::ConfigurationParser.new(
        workflow_yml_path,
        [],
        { output: output_file.path }
      )
      parser.begin!

      # Read the result
      result = File.read(output_file.path)

      # Parse JSON from result (handles markdown code blocks)
      parse_json_result(result)
    end
  end

  private

  def parse_json_result(result)
    # Extract JSON from markdown code blocks if present
    json_match = result.match(/```json\n(.*?)\n```/m)
    json_content = json_match ? json_match[1] : result

    JSON.parse(json_content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse workflow JSON result: #{e.message}"
    { error: "Failed to parse result", raw_output: result }
  end
end
