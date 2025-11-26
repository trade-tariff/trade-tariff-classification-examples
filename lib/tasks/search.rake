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

  desc "Restore commodities index from a JSONL file"
  task :restore_commodities, [:file_path] => :environment do |_, args|
    file_path = args[:file_path] || Rails.root.join("data/commodities_dump.jsonl")

    unless file_path.present? && File.exist?(file_path)
      puts "Please provide a valid file path."
      puts "Usage: rake search:restore_commodities[path/to/your/file.jsonl]"
      next
    end

    client = TradeTariffClassificationExamples.search_client
    index = CommodityIndex.new
    index_name = index.name
    batch = []
    batch_size = 1000

    puts "Clearing existing commodities index '#{index_name}'..."
    client.drop_index(index)
    client.create_index(index)

    puts "Restoring commodities from #{file_path} to index '#{index_name}'..."

    File.foreach(file_path) do |line|
      data = JSON.parse(line)
      id = data["commodity_code"]

      batch << { index: { _index: index_name, _id: id } }
      batch << data

      if batch.size / 2 >= batch_size
        client.__getobj__.bulk(body: batch)
        puts "Indexed #{batch.size / 2} documents..."
        batch = []
      end
    end

    # Index any remaining documents
    unless batch.empty?
      client.__getobj__.bulk(body: batch)
      puts "Indexed remaining #{batch.size / 2} documents."
    end

    puts "Finished restoring commodities."
  end
end
