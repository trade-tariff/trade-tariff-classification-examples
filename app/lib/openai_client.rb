require "faraday"
require "json"

class OpenaiClient
  MODEL = "gpt-5.1-2025-11-13".freeze

  MODEL_CONFIGS = {
    # GPT-5 Series (flagship, adaptive reasoning)
    "gpt-5.1-2025-11-13" => { reasoning_effort: "none" }, # Latest flagship with extended caching & coding
    "gpt-5-2025-10-03" => { reasoning_effort: "high" }, # Updated base GPT-5 for general tasks

    # o-Series (advanced reasoning previews)
    "o3-pro-2025-06-10" => { reasoning_effort: "high" },   # Pro version of o3 for complex reasoning
    "o1-pro" => { reasoning_effort: "high" },              # o1 Pro for agentic tasks
    "o1-preview" => { reasoning_effort: "high" },          # Original o1 preview
    "o1-mini" => { reasoning_effort: "high" },             # Lightweight o1 variant

    # GPT-5-Codex (coding-focused)
    "gpt-5-codex-max-2025-11-19" => { reasoning_effort: "high" }, # Max version for heavy coding/reasoning
    "gpt-5-codex-mini" => { reasoning_effort: "medium" }, # Mini for balanced speed/coding

    # GPT-4 Series (legacy, no full reasoning support)
    "gpt-4o-2024-08-06" => {},     # Multimodal GPT-4o
    "gpt-4o-mini" => {},           # Efficient mini variant
    "gpt-4.5" => {},               # Transitional model

    # Specialized (realtime/audio, limited reasoning)
    "gpt-realtime" => {},          # Realtime text/audio I/O
    "gpt-audio" => {},             # Audio-focused completions
  }.freeze

  class << self
    def call(context, model: MODEL)
      instrument do
        new.call(context, model: model)
      end
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "OpenAIClient call took #{duration.round(2)} seconds"
    end

    def client
      @client ||= Faraday.new(url: "https://api.openai.com") do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.headers["Accept"] = "application/json"
        faraday.headers["Content-Type"] = "application/json"
        faraday.headers["Authorization"] = "Bearer #{TradeTariffClassificationExamples.openai_api_key}"
        faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
        faraday.response :json, content_type: /\bjson$/
        faraday.options.timeout = 180
        faraday.options.open_timeout = 60
      end
    end
  end

  def call(context, model: MODEL)
    messages = if context.is_a?(Array)
                 context
               else
                 [{ role: "user", content: context.to_s }]
               end

    # Exact match on full model name for config (simple key lookup)
    config = MODEL_CONFIGS[model] || {}

    body_hash = {
      model: model,
      messages: messages,
      user: TradeTariffClassificationExamples.openai_user,
      response_format: { type: "json_object" },
    }.merge(config)

    body = body_hash.to_json

    response = self.class.client.post("/v1/chat/completions", body)

    if response.success?
      response.body.dig("choices", 0, "message", "content") || ""
    else
      Rails.logger.error "OpenAIClient error: #{response.body}"
      ""
    end
  end
end
