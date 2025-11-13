# goods_nomenclature_client.rb
require "faraday"
require "json"
require "logger"

class GoodsNomenclatureClient
  def call(code)
    search_response = get_endpoint(code)

    if search_response.dig("data", "type") == "exact_search"
      get_goods_nomenclature(search_response)
    else
      raise "Goods Nomenclature Not found"
    end
  end

  def self.client
    @client ||= Faraday.new(
      url: "https://www.trade-tariff.service.gov.uk",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
      },
    ) do |f|
      f.request  :json
      f.response :json, content_type: /\bjson$/
      f.adapter  Faraday.default_adapter
    end
  end

private

  attr_reader :client

  def get_endpoint(code)
    is_heading = (code.length == 6 && code.end_with?("00")) ||
      (code.length == 8 && code.end_with?("0000"))

    normalised_code = is_heading ? code[0, 4] : code

    response = safe_get("/api/v2/search?q=#{normalised_code}")

    unless response.success? && response.body.dig("data", "type") == "exact_search"
      normalised_code = code[0, 6]
      response = safe_get("/api/v2/search?q=#{normalised_code}")
    end

    raise "Not found" unless response.success?

    response.body
  end

  def get_goods_nomenclature(search_response)
    entry = search_response.dig("data", "attributes", "entry") || raise("Not found")

    endpoint = entry["endpoint"]
    id       = entry["id"]

    response = self.class.client.get("/api/v2/#{endpoint}/#{id}")

    raise "Not found" unless response.success?

    result = Hashie::Mash.new("_source" => response.body.dig("data", "attributes"))
    result._source.commodity_code = result._source.goods_nomenclature_item_id
    matching_selftexts = FetchRecords::ALL_GOODS_NOMENCLATURES.find do |g|
      code = result._source.goods_nomenclature_item_id
      pls = result._source.producline_suffix
      g[:goods_nomenclature_item_id] == "#{code}-#{pls}"
    end
    result._source.description = matching_selftexts[:description] if matching_selftexts.present?

    Commodity.wrap(result)
  end

  def safe_get(path)
    self.class.client.get(path)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    Rails.logger.error("Faraday error: #{e.class} - #{e.message}")
    OpenStruct.new(success?: false, status: nil, body: {})
  end
end
