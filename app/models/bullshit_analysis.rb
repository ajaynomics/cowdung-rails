class BullshitAnalysis < ApplicationRecord
  MODEL = "gpt-4o-mini"

  SYSTEM_PROMPT = <<~PROMPT
    You are a fact-checker and bullshit detector focused on SERIOUS lies and misinformation. Be chill about normal speech patterns and only call out actual bullshit.

    What to detect:
    - Obvious factual errors: "The sky is green", "2+2=5", "The earth is flat"
    - Dangerous misinformation: False medical claims, conspiracy theories
    - Blatant lies: Contradicting known facts or earlier statements
    - Impossible claims: "I can fly", "I invented the internet", "I'm 200 years old"
    - Extreme exaggerations: "This will make you rich overnight", "100% guaranteed", "Never fails"
    - Scams and deception: Get-rich-quick schemes, fake credentials

    What to IGNORE (fair comment):
    - Mild exaggeration for effect ("This is the best pizza ever")
    - Corporate speak (annoying but not dangerous)
    - Personal opinions ("I think this policy is wrong")
    - Speculation clearly marked as such ("Maybe...", "I wonder if...")
    - Metaphors and figures of speech
    - Enthusiasm or sales talk that's not deceptive

    Only flag something if it's genuinely misleading or factually wrong. Don't be a pedant.

    IMPORTANT: You will receive ALL prior BS detections for this session. Check if the current BS is essentially the same as something already detected:
    - Same false claim being repeated (e.g. "sky is green" detected before, now saying "sky is green" again)
    - Same type of misinformation about the same topic
    - Continuing the same scam or impossible claim

    If it's the same BS as before, mark is_duplicate as true. Only mark as false if it's a DIFFERENT lie/error.

    Always respond with this exact JSON structure:
    {
      "bullshit_detected": true/false,
      "confidence": 0.0-1.0,
      "type": "lie|misinformation|impossible|scam|contradiction",
      "explanation": "Brief explanation of why this is actually bullshit",
      "quote": "The specific false claim",
      "is_duplicate": true/false
    }
  PROMPT

  validates :session_id, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :detected, -> { where(detected: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :not_duplicate, -> { where(is_duplicate: false) }

  def self.analyze_transcript(session_id, transcript_text, all_prior_detections = nil)
    return nil if transcript_text.blank? || transcript_text.length < 30

    # Get ALL prior detections for this session
    all_prior_detections ||= for_session(session_id)
                            .detected
                            .where(is_duplicate: false) # Only consider non-duplicate detections
                            .order(created_at: :desc)

    # Prepare context about ALL prior detections
    prior_context = if all_prior_detections.any?
      prior_summary = all_prior_detections.map do |d|
        "- #{d.bs_type}: \"#{d.quote}\" (#{d.explanation})"
      end.join("\n")

      "\n\nALL prior BS detections for this session:\n#{prior_summary}"
    else
      ""
    end

    # Perform the analysis
    client = Raix.configuration.openai_client
    response = client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: "Analyze this transcript for bullshit:\n\n#{transcript_text}#{prior_context}" }
        ],
        response_format: { type: "json_object" },
        temperature: 0.7
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))

    Rails.logger.info "Bullshit detection result: #{result.inspect}"

    # Always create a record, but mark duplicates
    create!(
      session_id: session_id,
      detected: result["bullshit_detected"] || false,
      confidence: result["confidence"],
      bs_type: result["type"],
      explanation: result["explanation"],
      quote: result["quote"],
      analyzed_text: transcript_text,
      is_duplicate: result["is_duplicate"] || false
    )
  rescue => e
    Rails.logger.error "Bullshit detection failed: #{e.message}"

    # Create a failed analysis record
    create!(
      session_id: session_id,
      detected: false,
      analyzed_text: transcript_text,
      explanation: "Analysis failed: #{e.message}",
      is_duplicate: false
    )
  end
end
