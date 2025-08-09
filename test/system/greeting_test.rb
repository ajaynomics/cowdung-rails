require "application_system_test_case"

class GreetingTest < ApplicationSystemTestCase
  test "user can view AI greeting page" do
    visit greeting_path

    assert_text "AI Greeting"
    assert_text "You asked: \"How are you today?\""

    # Verify response area exists and has content
    within ".bg-gray-50" do
      assert_selector "p"
    end
  end
end
