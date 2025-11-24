class NonInteractiveSearch
  def initialize(query)
    @query = query
  end

  def call
    results = search_client.search(
      index: CommodityIndex.new.name,
      body: {
        query: {
          multi_match: {
            query: query,
            fields: ["commodity_code^2", "searchable_description"],
          },
        },
        size: 10,
        from: 0,
        sort: [],
      },
    )

    Commodity.wrap(results.hits.hits)
  end

  delegate :search_client, to: TradeTariffClassificationExamples

private

  attr_reader :query
end
