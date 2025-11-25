class InteractiveMemory
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates :search_input, presence: true

  attribute :search_input
  attribute :opensearch_answers, default: []
  attribute :questions, default: []
  attribute :final_answers, default: []

  CONFIDENCE_LEVELS = {
    "high" => 3,
    "medium" => 2,
    "low" => 1,
    "unknown" => 0,
  }.freeze

  def final_answer?
    final_answers.any?
  end

  def final_commodities
    final_answers.each_with_object([]) do |answer, acc|
      code = answer[:commodity_code]
      description = lookup_description(code)
      opensearch_commodity = opensearch_answers.find do |result|
        result.commodity_code == code
      end

      acc << Commodity.new(
        commodity_code: answer[:commodity_code],
        description: description || "",
        score: nil,
        known_brands: opensearch_commodity&.known_brands || [],
        colloquial_terms: opensearch_commodity&.colloquial_terms || [],
        synonyms: opensearch_commodity&.synonyms || [],
        original_description: opensearch_commodity&.original_description || "",
        confidence: answer[:confidence] || "unknown",
      )
    end
  end

  def add_question(data, answer: nil)
    attrs = {
      index: next_index,
      text: data[:text],
      options: data[:options] || %w[Yes No],
    }
    attrs[:answer] = answer if answer.present?

    questions << Question.new(attrs)
  end

  def questions_unanswered?
    unanswered_questions.any?
  end

  def all_questions_answered?
    unanswered_questions.none?
  end

  def unanswered_questions
    questions.reject(&:answered?)
  end

private

  def lookup_description(code)
    FetchRecords::ALL_GOODS_NOMENCLATURES.find { |g|
      g[:goods_nomenclature_item_id].include?(code)
    }.try(:[], :description)
  end

  def next_index
    questions.size
  end
end
