class ExpandSearchQuery
  attr_reader :search_query

  def initialize(search_query)
    @search_query = search_query
  end

  def call
    context = I18n.t("contexts.expand_search_query.instructions", search_query: @search_query)

    result = TradeTariffClassificationExamples.ai_client.call(context)
    parsed = ExtractBottomJson.new.call(result)

    parsed["expanded_query"]
  end
end
