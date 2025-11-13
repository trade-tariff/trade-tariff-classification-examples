class QuestionCollection
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates :search_input, presence: true

  validates :final_commodity_code_answer, format: { with: /\A\d{6,10}\z/, message: "must be 6 to 10 digits" }, allow_blank: true
  validates :final_commodity_code_description, presence: true, if: -> { final_commodity_code_answer.present? }

  attribute :search_input
  attribute :elasticsearch_answers, default: []
  attribute :questions, default: []
  attribute :final_commodity_code_answer, :string, default: ""
  attribute :final_commodity_code_description, :string, default: ""

  def add_question(text, answer: nil)
    attrs = {
      index: next_index,
      text: text,
      options: %w[Yes No],
    }
    attrs[:answer] = answer if answer.present?

    questions << Question.new(attrs)
  end

  def add_question_json(question)
    questions << question
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

  def next_index
    questions.size
  end
end
