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
      attributes.id = item._id
      attributes.score = item._score

      Commodity.new(attributes.to_h)
    end
  end

private

  def searchable_brands
    known_brands.to_a.join(" ")
  end

  def searchable_colloquial_terms
    colloquial_terms.to_a.join(" ")
  end

  def searchable_synonyms
    synonyms.to_a.join(" ")
  end
end
