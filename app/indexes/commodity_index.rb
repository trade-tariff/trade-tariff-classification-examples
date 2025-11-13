class CommodityIndex
  INDEX_NAME = "commodities".freeze

  def self.build(file = Rails.root.join("data/labelled_commodities.json"))
    augmented_commodities = JSON.parse(File.read(file))
    entries = augmented_commodities.map do |commodity_data|
      Commodity.new(commodity_data).tap do |commodity|
        commodity.id = commodity.commodity_code
      end
    end

    BuildIndex.new(new, entries).call
  end

  def serialize_entry(entry)
    {
      searchable_description: entry.searchable_description,
      commodity_code: entry.commodity_code,
      description: entry.description,
      known_brands: entry.known_brands,
      colloquial_terms: entry.colloquial_terms,
      synonyms: entry.synonyms,
    }
  end

  def name
    [TradeTariffClassificationExamples.server_namespace, INDEX_NAME].join("-")
  end

  def definition
    {
      mappings: {
        properties: {
          searchable_description: { type: "text", analyzer: "snowball" },
          commodity_code: {
            type: "text",
            "fields": {
              "keyword": {
                "type": "keyword",
                "ignore_above": 256,
              },
            },
            analyzer: "ngram_analyzer",
            search_analyzer: "lowercase_analyzer",
          },
          description: { enabled: false },
          original_description: { enabled: false },
          known_brands: { enabled: false },
          colloquial_terms: { enabled: false },
          synonyms: { enabled: false },
        },
      },
      settings: {
        analysis: {
          filter: {
            ngram_filter: {
              type: "edge_ngram",
              min_gram: 2,
              max_gram: 20,
            },
          },
          analyzer: {
            ngram_analyzer: {
              type: "custom",
              tokenizer: "standard",
              filter: %w[lowercase ngram_filter],
            },
            lowercase_analyzer: {
              type: "custom",
              tokenizer: "standard",
              filter: %w[lowercase],
            },
          },
        },
      },
    }
  end
end
