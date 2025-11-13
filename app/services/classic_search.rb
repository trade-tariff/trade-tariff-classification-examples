# frozen_string_literal: true

class ClassicSearch
  def initialize(query)
    @query = query
  end

  def call
    response = client.post("/uk/api/search", { q: query }.to_json)

    @result = Hashie::Mash.new(response.body)

    if @result.data.type == "fuzzy_match"
      fuzzy_match(result)
    else
      exact_match(result)
    end
  end

private

  def fuzzy_match(result)
    Commodity.wrap(result.commodities).first.description
  end

  def exact_match(result)
    url = "/uk/api/#{result.data.attributes.entry.endpoint}/#{result.data.attributes.entry.id}"

    response = client.get(url)

    Commodity.wrap(TariffJsonapiParser.new(response.body).parse)
  rescue Faraday::ResourceNotFound
    []
  end

  attr_reader :query

  def client
    Faraday.new(url: "https://staging.trade-tariff.service.gov.uk") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers["Accept"] = "application/vnd.hmrc.2.0+json"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
      faraday.response :json, content_type: /\bjson$/
    end
  end
end
