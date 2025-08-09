# frozen_string_literal: true

require "roast"

# Configure Raix with OpenAI client
Raix.configure do |config|
  api_key = Rails.configuration.x.openai.api_key
  Rails.logger.info "Configuring Raix with API key: #{api_key&.first(20)}..."

  config.openai_client = OpenAI::Client.new(
    access_token: api_key,
    uri_base: "https://api.openai.com/v1",
    log_errors: Rails.env.development?
  )
end
