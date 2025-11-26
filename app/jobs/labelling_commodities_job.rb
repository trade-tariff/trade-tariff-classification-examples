# frozen_string_literal: true

class LabellingCommoditiesJob < ApplicationJob
  queue_as :default

  def perform(commodities)
    Rails.logger.info "Starting to label #{commodities.size} commodities"
    entries = LabelCommodities.new(commodities).call

    entries = entries.map do |entry|
      Commodity.new(entry).tap do |commodity|
        commodity.id = commodity.commodity_code
        commodity.original_description = find_original_description(commodity.commodity_code, commodities)
      end
    end

    index_batch(entries)

    Rails.logger.info "Finished labelling commodities"
  end

private

  delegate :search_client, :opensearch_client, to: TradeTariffClassificationExamples

  def index_batch(entries)
    index = CommodityIndex.new
    opensearch_client.bulk(
      body: serialize_for(
        :index,
        index,
        entries,
      ),
    )
  end

  def find_original_description(commodity_code, commodities)
    commodity = commodities.find { |c| c[:goods_nomenclature_item_id] == commodity_code }
    commodity ? commodity[:description] : nil
  end

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |entry, memo|
      memo.push(
        operation => {
          _id: entry.id,
          _index: index.name,
          data: index.serialize_entry(entry),
        },
      )
    end
  end
end
