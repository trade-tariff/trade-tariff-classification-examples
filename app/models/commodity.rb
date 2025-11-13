class Commodity
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :commodity_code, :string
  attribute :original_description, :string
  attribute :description, :string
  attribute :known_brands, array: true, default: []
  attribute :colloquial_terms, array: true, default: []
  attribute :synonyms, array: true, default: []
  attribute :score, :float

  def searchable_description
    "#{description} #{searchable_brands} #{searchable_colloquial_terms} #{searchable_synonyms}".strip
  end

  def self.wrap(results)
    Array.wrap(results).map do |item|
      attributes = item._source.slice(*attribute_names)
      attributes.id = item._id if item._id
      attributes.score = item._score if item._score

      Commodity.new(attributes.to_h)
    end
  end

  def as_json(_options = {})
    {
      commodity_code: commodity_code,
      description: description,
      known_brands: known_brands,
      colloquial_terms: colloquial_terms,
      synonyms: synonyms,
      score: score,
      original_description: original_description,
    }
  end

private

  def searchable_brands
    handle_string(known_brands)
  end

  def searchable_colloquial_terms
    handle_string(colloquial_terms)
  end

  def searchable_synonyms
    handle_string(synonyms)
  end

  def handle_string(value)
    Array.wrap(value).to_a.join(" ")
  end
end
