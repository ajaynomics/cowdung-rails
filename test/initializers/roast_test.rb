require "test_helper"

class RoastInitializerTest < ActiveSupport::TestCase
  test "openai configuration is loaded from yaml" do
    assert Rails.configuration.x.openai.present?
    assert_respond_to Rails.configuration.x.openai, :api_key
  end

  test "raix is configured with a client" do
    assert Raix.configuration.openai_client.present?
    assert_respond_to Raix.configuration.openai_client, :chat
  end
end
