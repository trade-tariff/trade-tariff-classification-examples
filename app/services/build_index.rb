class BuildIndex
  def initialize(index, entries = [])
    @index = index
    @entries = entries
  end

  def call
    return true if @entries.empty?

    search_client.drop_index(index) if search_client.index_exists?(index)
    search_client.create_index(index)
    opensearch_client.bulk(
      body: serialize_for(
        :index,
        index,
        entries,
      ),
    )
  end

private

  attr_reader :index, :entries

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |entry, memo|
      memo.push(
        operation => {
          _index: index.name,
          data: index.serialize_entry(entry),
        },
      )
    end
  end

  delegate :search_client, :opensearch_client, to: TradeTariffClassificationExamples
end
