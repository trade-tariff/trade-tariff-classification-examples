class LabelMissingCommodities
  class << self
    def call(dry_run: false)
      instrument(dry_run:) { |**args| new(**args).call }
    end

    def instrument(dry_run: false)
      start_time = Time.zone.now
      yield(dry_run:)
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "LabelMissingCommodities call took #{duration.round(2)} seconds"
    end
  end

  def initialize(dry_run: false)
    @dry_run = dry_run
  end

  def call
    Rails.logger.info("Labelling missing commodities started")
    label_missing_commodities
    Rails.logger.info("Finished labelling missing commodities")
  end

private

  attr_reader :dry_run

  def label_missing_commodities
    Rails.logger.info("Starting to find and label missing commodities")

    source_file = "data/commodities_uk_2025_11_27.csv"
    missing_commodities = []
    processed_count = 0

    CSV.foreach(source_file, headers: true) do |row|
      processed_count += 1
      commodity_code = row["Commodity code"]
      klass = row["Class"]

      next unless klass.in?(%w[Commodity])
      next if TradeTariffClassificationExamples.search_client.exists?(CommodityIndex.new.name, commodity_code)

      missing_commodities << row.to_h
    end

    Rails.logger.info("Found #{missing_commodities.size} missing commodities")
    Rails.logger.info("Processed #{processed_count} commodities in total")
    Rails.logger.info("#{processed_count - missing_commodities.count} commodities already present")

    return if missing_commodities.empty?

    batch = []

    normalised_commodities = missing_commodities.map.with_index { |commodity_row, index|
      Rails.logger.info("Normalising #{index + 1}/#{missing_commodities.size}: #{commodity_row['Commodity code']}")

      if batch.size >= TradeTariffClassificationExamples.batch_size
        LabellingCommoditiesJob.perform_later(batch)
        batch = []
      end

      begin
        commodity = GoodsNomenclatureClient.new.call(commodity_row["Commodity code"]).first

        batch << {
          "goods_nomenclature_item_id" => commodity.commodity_code,
          "description" => commodity.original_description.presence || commodity.description,
        }
      rescue StandardError => e
        Rails.logger.error("Failed to normalise commodity #{commodity_row['Commodity code']}: #{e.message}")
        nil
      end
    }.compact

    if dry_run == "true"
      Rails.logger.info("Dry run: would have labelled #{normalised_commodities.size} commodities")
      return
    end
    Rails.logger.info("Normalised #{normalised_commodities.size} commodities")

    return if normalised_commodities.empty?

    normalised_commodities
  end
end
