require "test_helper"

class RoastInitializerTest < ActiveSupport::TestCase
  test "openai configuration is loaded" do
    assert Rails.configuration.x.openai.present?
    assert Rails.configuration.x.openai.api_key.present?
  end

  test "raix is configured with openai client" do
    assert Raix.configuration.openai_client.present?
  end
end
