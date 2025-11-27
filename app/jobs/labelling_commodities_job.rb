# frozen_string_literal: true

class LabellingCommoditiesJob < ApplicationJob
  queue_as :default

  # retry_on StandardError, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(commodities)
    Rails.logger.info "Starting to label #{commodities.size} commodities"
    entries = LabelCommodities.new(commodities).call

    entries = entries.map do |entry|
      entry = HashWithIndifferentAccess.new(entry)
      Commodity.new(entry).tap do |commodity|
        commodity.id = commodity.commodity_code

        original_description = commodity.original_description.presence || commodities.find { |c| c["goods_nomenclature_item_id"] == commodity.commodity_code }["original_description"]
        original_description ||= find_original_description(commodity.commodity_code, commodities)

        commodity.original_description = original_description
      end
    end

    index_batch(entries)

    Rails.logger.info "Finished labelling commodities"
  end

private

  delegate :search_client, :opensearch_client, to: TradeTariffClassificationExamples

  def index_batch(entries)
    index = CommodityIndex.new
    bulk_body = serialize_for(
      :index,
      index,
      entries,
    )

    Rails.logger.info "OpenSearch bulk body: #{bulk_body.to_json}"

    opensearch_client.bulk(
      body: bulk_body,
    )
  end

  def find_original_description(commodity_code, commodities)
    commodity = commodities.find { |c| c["goods_nomenclature_item_id"] == commodity_code }
    commodity ? commodity["description"] : nil
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
