# frozen_string_literal: true

class BatchLabelCommodities
  class << self
    def call
      instrument { new.call }
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "BatchLabelCommodities call took #{duration.round(2)} seconds"
    end
  end

  def call
    commodities_to_label.each_slice(batch_size) do |batch|
      LabellingCommoditiesJob.perform_later(batch)
    end
  end

private

  def commodities_to_label
    all_commodities = FetchRecords::COMMODITIES

    all_commodities.reject do |commodity|
      search_client.exists?(CommodityIndex.new.name, commodity[:goods_nomenclature_item_id])
    end
  end

  delegate :search_client, :batch_size, to: TradeTariffClassificationExamples
end
