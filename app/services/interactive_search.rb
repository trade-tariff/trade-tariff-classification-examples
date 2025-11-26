class InteractiveSearch
  def initialize(interactive_memory)
    @interactive_memory = interactive_memory
    @attempts = 0
  end

  def call
    while needs_more_questions?
      result = TradeTariffClassificationExamples.ai_client.call(search_context)
      @attempts += 1

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
    if interactive_memory.opensearch_answers.one?
      commodity = interactive_memory.opensearch_answers.first
      answer = {
        "commodity_code" => commodity.commodity_code,
        "confidence" => commodity.confidence,
      }

      add_answers(Array.wrap(answer))

      return false
    end

    if interactive_memory.opensearch_answers.empty?
      interactive_memory.search_commodity_form.errors.add(:query, :no_commodities_found)

      return false
    end

    return false if interactive_memory.final_answer?
    return false if interactive_memory.questions_unanswered?

    if @attempts >= TradeTariffClassificationExamples.interactive_search_max_attempts
      interactive_memory.search_commodity_form.errors.add(:query, :max_attempts_reached)
      return false
    end
    true
  end

  def search_context
    I18n.t(
      "contexts.interactive_search.instructions",
      answers_opensearch: interactive_memory.opensearch_answers.to_json,
      questions: interactive_memory.questions.sort_by(&:index).to_json,
      search_input: interactive_memory.search_input,
    ).tap do |context|
      File.write("log/interactive_search_context_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.txt", context) if Rails.env.development?
    end
  end

  def handle_result(result)
    result["search_input"] = interactive_memory.search_input
    timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S")
    File.write("log/interactive_search_#{timestamp}.json", JSON.pretty_generate(result)) if Rails.env.development?
    questions = extract_questions(result)

    # NOTE: We only ask one question at a time
    question = questions.first
    interactive_memory.add_question(question) if question.present?

    answers = result.fetch("answers", {})

    add_answers(answers) if answers.any?
  end

  def extract_questions(result)
    questions = []
    questions_aliases = %w[questions extra_questions]
    question_aliases = %w[question extra_question text]
    option_aliases = %w[options option_choices choices]
    questions_aliases.each do |alias_name|
      next unless result.key?(alias_name) && result[alias_name].is_a?(Array)

      result[alias_name].each do |question|
        case question
        when Hash
          text = ""
          question_aliases.each do |q_alias|
            if question.key?(q_alias)
              text = question[q_alias]
              break
            end
          end
          options = []
          option_aliases.each do |o_alias|
            if question.key?(o_alias) && question[o_alias].is_a?(Array)
              options = question[o_alias].map(&:to_s)
              break
            end
          end

          if options.empty?
            options = %w[Yes No]
          end

          questions << { text: text, options: options }
        when String
          questions << { text: question, options: %w[Yes No] }
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

  def add_answers(answers)
    interactive_memory.final_answers = answers.map do |answer|
      {
        commodity_code: answer["commodity_code"],
        confidence: answer["confidence"].to_s.downcase,
      }
    end
  end
end
