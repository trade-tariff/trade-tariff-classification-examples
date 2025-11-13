class InteractiveSearch
  def initialize(interactive_memory)
    @interactive_memory = interactive_memory
  end

  def call
    while needs_more_questions?
      result = TradeTariffClassificationExamples.ai_client.call(search_context)

      begin
        parsed_result = ExtractBottomJson.new.call(result)
        handle_result(parsed_result)
      rescue StandardError
        Rails.logger.info "Failed to parse JSON response: #{result}"
      end
    end

    interactive_memory
  end

private

  attr_reader :interactive_memory

  def needs_more_questions?
    return false if interactive_memory.final_commodity_code_answer.present?
    return false if interactive_memory.questions_unanswered?

    true
  end

  def search_context
    I18n.t(
      "contexts.interactive_search.instructions",
      answers_elasticsearch: interactive_memory.elasticsearch_answers.to_json,
      questions: interactive_memory.questions.sort_by(&:index).to_json,
      search_input: interactive_memory.search_input,
    ).tap do |context|
      File.write(Rails.root.join("log/interactive_search_context_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.txt"), context)
    end
  end

  def handle_result(result)
    result["search_input"] = interactive_memory.search_input
    timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S")
    File.write(Rails.root.join("log/interactive_search_#{timestamp}.json"), JSON.pretty_generate(result))
    questions = extract_questions(result)

    questions.each { |text| interactive_memory.add_question(text) } if questions.present?

    code = extract_code(result)

    if code.present?
      interactive_memory.final_commodity_code_answer = code
      interactive_memory.final_commodity_code_description = lookup_description(code)
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
    FetchRecords::ALL_GOODS_NOMENCLATURES.find { |g|
      g[:goods_nomenclature_item_id].include?(code)
    }.try(:[], :description)
  end
end
