class Question
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates :text, presence: true

  validates :index,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :validate_answer

  attribute :index, :integer
  attribute :text, :string
  attribute :answer, :string, default: ""
  attribute :options, array: true, default: %w[Yes No]

  def validate_answer
    return if answer.blank?

    unless options.include?(answer)
      errors.add(:answer, "is not included in the available options")
    end
  end

  def answered?
    answer.present?
  end

  def question_options
    options.map { |option| OpenStruct.new(id: option, name: option) }
  end

  def as_json(*)
    {
      index: index,
      text: text,
      answer: answer,
      options: options,
    }
  end
end
