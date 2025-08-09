require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "audio page renders with recording interface" do
    get audio_path
    assert_response :success
    assert_select "h1", "Audio Recorder"
    assert_select "button[data-audio-recorder-target='button']"
    assert_select "[data-controller='audio-recorder']"
  end

  test "greeting page renders successfully" do
    # Stub OpenAI API call
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

    get greeting_path
    assert_response :success
    assert_select "h1", "AI Greeting"
    assert_select "p", text: /You asked: "How are you today\?"/
    assert_match "Hello from Roast!", response.body
  end
end
