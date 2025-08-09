require "test_helper"

class RunExampleWorkflowJobTest < ActiveJob::TestCase
  test "job processes input text through workflow" do
    # Test that the job executes without error
    assert_nothing_raised do
      RunExampleWorkflowJob.perform_now("Test input")
    end
  end

  test "job handles workflow errors gracefully" do
    # Test with empty input
    result = RunExampleWorkflowJob.perform_now("")

    # Should return a hash (either success or error structure)
    assert result.is_a?(Hash)
  end
end
