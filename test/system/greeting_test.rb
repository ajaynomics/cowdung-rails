require "application_system_test_case"

class GreetingTest < ApplicationSystemTestCase
  test "user can view AI greeting page" do
    # System tests run in a separate process, so WebMock is the appropriate tool here
    # This is the "last resort" scenario where WebMock is justified
    WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: "Hello from Roast!"
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    visit greeting_path

    assert_text "AI Greeting"
    assert_text "You asked: \"How are you today?\""
    assert_text "Hello from Roast!"
  end
end
