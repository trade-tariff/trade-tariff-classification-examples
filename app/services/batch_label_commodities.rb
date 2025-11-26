# frozen_string_literal: true

class BatchLabelCommodities
  class << self
    def call(dry_run: false)
      instrument(dry_run:) { |**args| new.call(**args) }
    end

    def instrument(dry_run: false)
      start_time = Time.zone.now
      yield(dry_run:)
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "BatchLabelCommodities call took #{duration.round(2)} seconds"
    end
  end

  def call(dry_run: false)
    if dry_run
      Rails.logger.info "Dry run: #{commodities_to_label.size} commodities to be labelled in batches of #{batch_size}"

      commodities_to_label.each_slice(batch_size) do |batch|
        Rails.logger.info "Dry run: would label batch of #{batch.size} commodities"
      end
    else
      Rails.logger.info "Labelling #{commodities_to_label.size} commodities in batches of #{batch_size}"
      commodities_to_label.each_slice(batch_size) do |batch|
        # LabellingCommoditiesJob.perform_later(batch)
      end
    end
  end

private

  def commodities_to_label
    @commodities_to_label ||=
      begin
        all_commodities = FetchRecords::COMMODITIES

        all_commodities.reject do |commodity|
          search_client.exists?(CommodityIndex.new.name, commodity[:goods_nomenclature_item_id])
        end
      end
  end

  delegate :search_client, :batch_size, to: TradeTariffClassificationExamples
end
