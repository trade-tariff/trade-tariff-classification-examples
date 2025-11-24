class NeuralNetSearch
  def initialize(query)
    @query = query
  end

  def call
    response = client.post(
      "/fpo-code-search",
      {
        description: query,
        digits: 8,
        limit: 10,
      }.to_json,
    )

    result = Hashie::Mash.new(response.body)

    result.results.map { |result|
      code = result.code
      score = result.score
      commodity = GoodsNomenclatureClient.new.call(code)&.first

      if commodity
        commodity.score = score
        commodity
      end
    }.compact
  end

private

  attr_reader :query

  def client
    Faraday.new(url: "https://search.dev.trade-tariff.service.gov.uk") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers["Accept"] = "application/json"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
      faraday.headers["X-Api-Key"] = TradeTariffClassificationExamples.fpo_search_api_key
      faraday.response :json, content_type: /\bjson$/
    end
  end
end
