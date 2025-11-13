require "faraday"
require "json"

class OpenaiClient
  MODEL = "gpt-4o".freeze

  def self.call(context, model: MODEL)
    instrument do
      new.call(context, model: model)
    end
  end

  def call(context, model: MODEL)
    messages = if context.is_a?(Array)
                 context
               else
                 [{ role: "user", content: context.to_s }]
               end

    body = {
      model: model,
      messages: messages,
      user: TradeTariffClassificationExamples.openai_user,
    }.to_json

    response = self.class.client.post("/v1/chat/completions", body)

    if response.success?
      content = response.body.dig("choices", 0, "message", "content") || ""
      content.strip.gsub("```json", "").gsub("```", "").strip
    else
      Rails.logger.error "OpenAIClient error: #{response.body}"
      ""
    end
  end

  def self.instrument
    start_time = Time.zone.now
    yield
  ensure
    end_time = Time.zone.now
    duration = end_time - start_time
    Rails.logger.info "OpenAIClient call took #{duration.round(2)} seconds"
  end

  def self.client
    @client ||= Faraday.new(url: "https://api.openai.com") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers["Accept"] = "application/json"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["Authorization"] = "Bearer #{TradeTariffClassificationExamples.openai_api_key}"
      faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
      faraday.response :json, content_type: /\bjson$/
    end
  end
end
