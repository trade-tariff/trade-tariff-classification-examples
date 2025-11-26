# rubocop:disable Rails/SaveBang
class SearchClient < SimpleDelegator
  QueryError = Class.new(StandardError)

  attr_reader :indexes

  def initialize(search_client, options = {})
    @indexes = options.fetch(:indexes, [])

    super(search_client)
  end

  def search(*)
    Hashie::Mash.new(super)
  end

  def msearch(*)
    Hashie::Mash.new(super)
  end

  def reindex_all
    indexes.each(&method(:reindex))
  end

  def reindex(index)
    drop_index(index)
    create_index(index)
    build_index(index)
  end

  def update_all
    indexes.each(&method(:update))
  end

  def update(index)
    create_index(index)
    build_index(index)
  end

  def create_index(index)
    indices.create(index: index.name, body: index.definition) unless indices.exists(index: index.name)
  end

  def drop_index(index)
    indices.delete(index: index.name) if indices.exists(index: index.name)
  end

  def index(index_class, model)
    model_index = index_class.new

    super({
      index: model_index.name,
      id: model.id,
      body: model_index.serialize_record(model).as_json,
    }.merge(search_operation_options))
  end

  def index_by_name(index_name, model_id, model_json)
    __getobj__.index({
      index: index_name,
      id: model_id,
      body: model_json,
    })
  end

  def delete(index_class, model)
    super({
      index: index_class.new.name,
      id: model.id,
    })
  end

  def delete_by_name(index_name, model_id)
    __getobj__.delete({
      index: index_name,
      id: model_id,
    })
  end

  def exists?(index_name, model_id)
    __getobj__.exists({
      index: index_name,
      id: model_id,
    })
  end
end
# rubocop:enable Rails/SaveBang
