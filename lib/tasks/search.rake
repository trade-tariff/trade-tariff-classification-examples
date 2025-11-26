# frozen_string_literal: true

require "json"

namespace :search do
  desc "Rebuild all search indexes from scratch"
  task reindex: :environment do
    TradeTariffClassificationExamples.search_client.reindex_all
  end

  desc "Create all search indexes"
  task create: :environment do
    TradeTariffClassificationExamples.search_client.indexes.each do |index|
      TradeTariffClassificationExamples.search_client.create_index(index)
    end
  end

  desc "Drop all search indexes"
  task drop: :environment do
    TradeTariffClassificationExamples.search_client.indexes.each do |index|
      TradeTariffClassificationExamples.search_client.drop_index(index)
    end
  end

  desc "Dump commodities index to a JSONL file"
  task dump_commodities: :environment do
    file_path = Rails.root.join("data/commodities_dump.jsonl")
    File.open(file_path, "w") do |file|
      response = TradeTariffClassificationExamples.search_client.search(
        index: CommodityIndex.new.name,
        scroll: "1m",
        body: {
          query: {
            match_all: {},
          },
        },
      )

      # First batch of results
      response["hits"]["hits"].each do |hit|
        file.puts(JSON.generate(hit["_source"]))
      end

      # Subsequent batches using scroll API
      while (response = TradeTariffClassificationExamples.search_client.scroll(scroll_id: response["_scroll_id"], scroll: "1m")) && response["hits"]["hits"].any?
        response["hits"]["hits"].each do |hit|
          file.puts(JSON.generate(hit["_source"]))
        end
      end
    end
    puts "Commodities index dumped to #{file_path}"
  end
end
