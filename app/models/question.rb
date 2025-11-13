class Question
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates :text, presence: true

  validates :index,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :answer, inclusion: { in: %w[Yes No] }, allow_blank: true

  attribute :index, :integer
  attribute :text, :string
  attribute :answer, :string, default: ""
  attribute :options, array: true, default: %w[Yes No]

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
