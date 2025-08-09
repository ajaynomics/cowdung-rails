class BullshitAnalysis < ApplicationRecord
  MODEL = "gpt-4o-mini"

  SYSTEM_PROMPT = <<~PROMPT
    You are a skeptical bullshit detector. Your job is to analyze transcripts and identify ANY form of bullshit, deception, or empty rhetoric. Be aggressive in calling out BS.

    Types of bullshit to detect:
    - Corporate jargon: "synergies", "leverage", "paradigm shift", "move the needle", etc.
    - Evasive language: answering without really answering
    - Buzzword soup: lots of trendy terms with no substance
    - Exaggerated claims: "revolutionary", "game-changing", "10x", unrealistic promises
    - Vague statements: promises without specifics, timelines, or measurables
    - Marketing fluff: superlatives and hype without evidence
    - Contradictions: saying opposite things

    Be critical! If something sounds like corporate speak, marketing hype, or evasion, call it out.

    Always respond with this exact JSON structure:
    {
      "bullshit_detected": true/false,
      "confidence": 0.0-1.0,
      "type": "lie|jargon|evasion|buzzwords|contradiction|vague|exaggeration",
      "explanation": "Brief explanation of the BS detected",
      "quote": "The most BS quote from the text"
    }
  PROMPT

  validates :session_id, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :detected, -> { where(detected: true) }
  scope :recent, -> { order(created_at: :desc) }

  def self.analyze_transcript(session_id, transcript_text)
    return nil if transcript_text.blank? || transcript_text.length < 30

    # Check if we've analyzed similar text recently (within 5 seconds)
    recent_analysis = for_session(session_id)
                     .where("created_at > ?", 5.seconds.ago)
                     .where(analyzed_text: transcript_text)
                     .first

    return recent_analysis if recent_analysis

    # Perform the analysis
    client = Raix.configuration.openai_client
    response = client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: "Analyze this transcript for bullshit:\n\n#{transcript_text}" }
        ],
        response_format: { type: "json_object" },
        temperature: 0.7
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))

    Rails.logger.info "Bullshit detection result: #{result.inspect}"

    # Create and return the analysis record
    create!(
      session_id: session_id,
      detected: result["bullshit_detected"] || false,
      confidence: result["confidence"],
      bs_type: result["type"],
      explanation: result["explanation"],
      quote: result["quote"],
      analyzed_text: transcript_text
    )
  rescue => e
    Rails.logger.error "Bullshit detection failed: #{e.message}"

    # Create a failed analysis record
    create!(
      session_id: session_id,
      detected: false,
      analyzed_text: transcript_text,
      explanation: "Analysis failed: #{e.message}"
    )
  end
end
