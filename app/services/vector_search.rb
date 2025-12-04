class VectorSearch
  def initialize(query, limit: 10)
    @query = query
    @limit = limit
  end

  # curl --location 'https://ott-poc-vector-search-bbcxdpc2ebcrfpgp.uksouth-01.azurewebsites.net/api/search_commodities?code=YveeZFmHDHe06Zt77Mz7nOY7kOZlKV1uh0oaNj9Q1xcWAzFuV-uxKw%3D%3D' \
  # --header 'Content-Type: application/json' \
  # --data '{"query_text": "knitted scarf", "k": 25}'
  class << self
    def call(query, limit: 10)
      instrument do
        new(query, limit: limit).call
      end
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "VectorSearch call took #{duration.round(2)} seconds"
    end

    def client
      @client ||= Faraday.new(url: "https://ott-poc-vector-search-bbcxdpc2ebcrfpgp.uksouth-01.azurewebsites.net") do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.headers["Accept"] = "application/json"
        faraday.headers["Content-Type"] = "application/json"
        faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
        faraday.request :url_encoded
        faraday.response :json, content_type: /\bjson$/
        faraday.response :logger
      end
    end
  end

  def call
    response = self.class.client.get("/api/search_commodities?code=#{TradeTariffClassificationExamples.vector_search_code}") do |req|
      req.body = {
        query_text: @query,
        k: @limit,
      }.to_json
    end

    if response.success?
      results = response.body
      results.map do |item|
        code = item["id"]
        score = item["score"].to_f * 100.0

        commodity_for(code, score)
      end
    else
      []
    end
  end

private

  def commodity_for(code, score)
    normalised_code = code.ljust(10, "0")
    candidate_description = FetchRecords::COMMODITIES_HASH[normalised_code]

    if candidate_description.present?
      Commodity.new(
        commodity_code: normalised_code,
        description: candidate_description,
        score: score,
      )
    else
      GoodsNomenclatureClient.new.call(code).first.tap do |c|
        c.score = item["score"].to_f * 100.0
      end
    end
  end
end
