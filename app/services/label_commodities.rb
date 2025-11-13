class LabelCommodities
  def initialize(batch)
    @commodities = batch
  end

  def call
    context = I18n.t("contexts.label_commodity.instructions")
    context += "\n\n"
    context += commodities.to_json

    result = GeminiShellClient.call(context)

    begin
      parsed_result = Array.wrap(JSON.parse(result))

      parsed_result.map { |item|
        {
          id: item.fetch("commodity_code", ""),
          commodity_code: item.fetch("commodity_code", ""),
          description: item.fetch("description", ""),
          known_brands: item.fetch("known_brands", []),
          colloquial_terms: item.fetch("colloquial_terms", []),
          synonyms: item.fetch("synonyms", []),
          original_description: item.fetch("original_description", ""),
        }
      }.tap do |items|
        if items.size != commodities.size
          Rails.logger.info "Warning: Expected #{commodities.size} items but got #{items.size} items"
        end

        Rails.logger.info "Successfully augmented #{items.size} commodities"
      end
    rescue JSON::ParserError
      Rails.logger.info "Failed to parse JSON response: #{result}"
      nil
    end
  end

private

  attr_reader :commodities
end
