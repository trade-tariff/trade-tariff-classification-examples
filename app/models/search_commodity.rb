# frozen_string_literal: true

class SearchCommodity
  SESSION_KEY = :search_commodity

  include ActiveModel::Model

  attr_accessor :query,
                :search_type,
                :session

  validates :query, presence: true
  validates :search_type, inclusion: { in: %w[interactive non_interactive neural_net classic] }
  validates :search_type, presence: true

  class << self
    def build(params, session)
      params = params.require(:search_commodity)

      query = params[:query]
      search_type = params[:search_type]

      search_commodity = SearchCommodity.new(
        query: query,
        search_type: search_type,
        session: session,
      )

      data = session.try(:[], SESSION_KEY)

      return search_commodity if data.blank?
      return search_commodity.tap { |sc| clear_session(sc.session) } if data["query"] != query || data["search_type"] != search_type

      questions = data["questions"].map do |question_data|
        question = Question.new(
          index: question_data["index"],
          text: question_data["text"],
          answer: question_data["answer"],
          options: question_data["options"],
        )
        question
      end
      answers = params.permit(*questions.map { |q| "question_#{q.index}" })
      unanswered_questions = questions.reject(&:answered?)
      unanswered_questions.each do |question|
        answer = answers["question_#{question.index}"]
        question.answer = answer if answer.present?
      end
      search_commodity.assign_questions(questions)

      search_commodity
    end

    def clear_session(session)
      session.delete(SESSION_KEY) if session && session[SESSION_KEY]
    end
  end

  def save
    validate_answers

    return false unless valid?

    if session
      session[SESSION_KEY] = as_json
      true
    else
      false
    end
  end

  def assign_questions(questions = [])
    @questions = questions

    @questions.each do |question|
      define_singleton_method("question_#{question.index}=") do |answer|
        @questions.find { |q| q.index == question.index }.answer = answer
      end

      define_singleton_method("question_#{question.index}") do
        @questions.find { |q| q.index == question.index }.answer
      end

      define_singleton_method("question_#{question.index}_options") do
        question.question_options
      end
    end
  end

  def validate_answers
    @questions.each do |question|
      if question.answer.blank?
        errors.add("question_#{question.index}", "can't be blank")
      end
      next if question.valid?

      question.errors.each_value do |message|
        errors.add("question_#{question.index}", message)
      end
    end
  end

  def questions
    @questions || []
  end

  def answered_questions; end

  def unanswered_questions; end

  def persisted?
    false
  end

  def as_json(*)
    {
      query: query,
      search_type: search_type,
      questions: questions.map(&:as_json),
    }
  end
end
