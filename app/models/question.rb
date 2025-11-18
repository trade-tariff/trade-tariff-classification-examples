class Question
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates :text, presence: true

  validates :index,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  attribute :index, :integer
  attribute :text, :string
  attribute :answer, :string, default: ""
  attribute :options, array: true, default: []

  def answered?
    answer.present?
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
