class InteractiveSearch
  def initialize(question_collection)
    @question_collection = question_collection
  end

  def call
    while needs_more_questions?
      result = GeminiShellClient.call(search_context)

      begin
        parsed_result = ExtractBottomJson.new.call(result)
        handle_result(parsed_result)
      rescue StandardError
        Rails.logger.info "Failed to parse JSON response: #{result}"
      end
    end

    question_collection
  end

private

  attr_reader :question_collection

  def needs_more_questions?
    return false if question_collection.final_commodity_code_answer.present?
    return false if question_collection.questions_unanswered?

    true
  end

  def search_context
    I18n.t(
      "contexts.interactive_search.instructions",
      answers_elasticsearch: question_collection.elasticsearch_answers.to_json,
      questions: question_collection.questions.sort_by(&:index).to_json,
      search_input: question_collection.search_input,
    )
  end

  def handle_result(result)
    result["search_input"] = question_collection.search_input
    timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S")
    File.write(Rails.root.join("log/interactive_search_#{timestamp}.json"), JSON.pretty_generate(result))
    questions = extract_questions(result)

    questions.each { |text| question_collection.add_question(text) } if questions.present?

    code = extract_code(result)

    if code.present?
      question_collection.final_commodity_code_answer = code
      question_collection.final_commodity_code_description = lookup_description(code)
    end
  end

  def extract_questions(result)
    questions = []
    questions_aliases = %w[questions extra_questions]
    question_aliases = %w[question extra_question text]
    questions_aliases.each do |alias_name|
      next unless result.key?(alias_name) && result[alias_name].is_a?(Array)

      result[alias_name].each do |question|
        case question
        when Hash
          question_aliases.each do |q_alias|
            if question.key?(q_alias)
              questions << question[q_alias]
              break
            end
          end
        when String
          questions << question
        end
      end
    end

    questions
  end

  def extract_code(result)
    code_aliases = %w[commodity_code goods_nomenclature_item_id code answer]
    code_aliases.each do |alias_name|
      if result.key?(alias_name)
        value = result[alias_name]
        return value if value.is_a?(String) && value.match?(/\A\d{6,10}\z/)
      end
    end

    if result.key?("answer") && result["answer"].is_a?(Hash)
      extract_code(result["answer"])
    end
  end

  def lookup_description(code)
    FetchRecords::COMMODITIES.find { |commodity|
      commodity[:goods_nomenclature_item_id] == code
    }.try(:[], :description)
  end
end
