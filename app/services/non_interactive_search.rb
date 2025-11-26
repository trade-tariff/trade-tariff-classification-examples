class NonInteractiveSearch
  def initialize(query, limit: 10)
    @query = query
    @limit = limit
  end

  def call
    results = search_client.search(
      index: CommodityIndex.new.name,
      body: {
        query: {
          multi_match: {
            query: query,
            fields: [
              "commodity_code^4",
              "original_description^3",
              "searchable_description",
            ],
          },
        },
        size: limit,
        from: 0,
        sort: [],
      },
    )

    Commodity.wrap(results.hits.hits)
  end

  delegate :search_client, to: TradeTariffClassificationExamples

private

  attr_reader :query, :limit
end
