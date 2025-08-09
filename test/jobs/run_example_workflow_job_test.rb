require "test_helper"

class RunExampleWorkflowJobTest < ActiveJob::TestCase
  test "job executes workflow and returns parsed result" do
    expected_result = {
      "summary" => "Test input analyzed",
      "key_points" => [ "Point 1", "Point 2", "Point 3" ]
    }

    # Stub OpenAI API call for analyze workflow
    WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: expected_result.to_json
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = RunExampleWorkflowJob.perform_now("Test input")

    assert_equal expected_result, result
    assert_equal "Test input analyzed", result["summary"]
    assert_equal 3, result["key_points"].length
  end
end
