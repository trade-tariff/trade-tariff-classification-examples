# frozen_string_literal: true

class SearchCommodity
  SESSION_KEY = :search_commodity

  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :query,
                :search_type,
                :session,
                :expanded_query

  validates :query, presence: true
  validates :search_type, inclusion: { in: %w[interactive non_interactive neural_net classic] }
  validates :search_type, presence: true

  class << self
    def build(params, session)
      params = params.require(:search_commodity)

      query = params[:query]
      search_type = params[:search_type]
      expanded_query = params[:expanded_query]

      search_commodity = SearchCommodity.new(
        query: query,
        search_type: search_type,
        expanded_query: expanded_query,
        session: session,
      )

      search_commodity.expand_query!

      data = session.try(:[], SESSION_KEY)

      return search_commodity if data.blank?

      if data["query"] != query || data["search_type"] != search_type
        return search_commodity.tap do |sc|
          clear_session(sc.session)
          search_commodity.expanded_query = nil
          search_commodity.expand_query!
        end
      end

      questions = data["questions"].map do |question_data|
        Question.new(
          index: question_data["index"],
          text: question_data["text"],
          answer: question_data["answer"],
          options: question_data["options"],
        )
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
        errors.add(:"question_#{question.index}", :blank)
      end

      next if question.valid?

      question.errors.each do |error|
        errors.add(:"question_#{question.index}", error.message)
      end
    end
  end

  def questions
    @questions || []
  end

  def answered_questions
    questions.select(&:answered?)
  end

  def unanswered_questions
    questions.reject(&:answered?)
  end

  def persisted?
    false
  end

  def presented_query
    [query, expanded_query].compact.join(" ")
  end

  def expand_query!
    return if expanded_query.present?
    return if query.to_s.match?(/\d+\z/)
    return if search_type != "interactive"

    self.expanded_query = ExpandSearchQuery.new(query).call if expanded_query.blank?
  end

  def as_json(*)
    {
      query: query,
      search_type: search_type,
      expanded_query: expanded_query,
      questions: questions.map(&:as_json),
    }
  end
end
