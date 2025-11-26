# frozen_string_literal: true

class ClassicSearch
  def initialize(query)
    @query = query
  end

  def call
    response = self.class.client.post("/uk/api/search", { q: query }.to_json)

    @result = Hashie::Mash.new(response.body)

    if @result.data.type == "fuzzy_search"
      fuzzy_match
    else
      exact_match
    end
  end

private

  def fuzzy_match
    commodities = @result.data.attributes.goods_nomenclature_match.commodities
    commodities = commodities.map do |commodity|
      description = lookup_description(commodity._source.goods_nomenclature_item_id) || commodity._source.description
      description = (commodity._source.ancestor_descriptions[1..] << description).join(" > ") if description.downcase.match?(/other/)
      commodity._source.commodity_code = commodity._source.goods_nomenclature_item_id
      commodity._source.description = description
      commodity
    end
    Commodity.wrap(commodities).sort_by(&:score).reverse
  end

  def exact_match
    entry = @result.data.attributes.entry
    url = "/uk/api/#{entry.endpoint}/#{entry.id}"

    response = self.class.client.get(url)
    parsed = Hashie::Mash.new(TariffJsonapiParser.new(response.body).parse)

    attributes = parsed.slice(*Commodity.attribute_names)
    attributes.commodity_code = parsed.goods_nomenclature_item_id
    attributes.score = 100.0
    attributes.description = lookup_description(parsed.goods_nomenclature_item_id) || parsed.description

    [Commodity.new(attributes.to_h)]
  rescue Faraday::ResourceNotFound
    []
  end

  attr_reader :query

  def lookup_description(code)
    FetchRecords::COMMODITIES_HASH.dig(code, :description)
  end

  class << self
    def client
      @client ||= Faraday.new(url: "https://staging.trade-tariff.service.gov.uk") do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.headers["Accept"] = "application/vnd.hmrc.2.0+json"
        faraday.headers["Content-Type"] = "application/json"
        faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
        faraday.response :json, content_type: /\bjson$/
      end
    end

    def call(query)
      instrument do
        new(query).call
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
  end
end
