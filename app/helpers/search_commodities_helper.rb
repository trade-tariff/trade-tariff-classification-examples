module SearchCommoditiesHelper
  def questions_for(search_type, form)
    return unless search_type.interactive?

    if form.object.questions.present?
      question_radios = form.object.questions.map do |question|
        if question.answer.present?
          form.hidden_field :"question_#{question.index}", value: question.answer
        else
          form.govuk_collection_radio_buttons(
            :"question_#{question.index}",
            question.question_options,
            :id,
            :name,
            class: question.answer.present? ? "answered" : "",
            legend: { text: question.text, size: "m" },
            hint: { text: "" },
            include_hidden: true,
          )
        end
      end
      safe_join(question_radios)
    end
  end

  def render_commodity_table(results, max_score)
    govuk_table do |table|
      table.with_head do |head|
        head.with_row do |row|
          row.with_cell(text: "Confidence")
          row.with_cell(text: "Description")
          row.with_cell
        end
      end

      table.with_body do |body|
        results.each do |commodity|
          body.with_row(html_attributes: { id: "commodity-#{commodity.commodity_code}-score-#{commodity.score}" }) do |row|
            row.with_cell(text: commodity_confidence(commodity, max_score))
            row.with_cell(text: commodity.description)
            row.with_cell(text: govuk_button_link_to("Select", "https://trade-tariff.service.gov.uk/commodities/#{commodity.commodity_code}", class: "govuk-!-float-right", target: "_blank", rel: "noopener"))
          end
        end
      end
    end
  end

private

  def commodity_confidence(commodity, max_score)
    text = if commodity.confidence.present?
             "#{commodity.confidence.titleize} match"
           else
             score_to_text(commodity.score, max_score)
           end

    govuk_tag(text: text, colour: "blue")
  end

  def score_to_text(score, max_score)
    # OpenSearch scores are relative. We map the score to a qualitative
    # label based on its ratio to the highest score in the result set.
    # These labels are intended to give a general sense of relevance.
    ratio = max_score.to_f.positive? ? score.to_f / max_score : 0

    case ratio
    when 0.8..1.0
      "Strong match"
    when 0.5..0.8
      "Good match"
    when 0.2..0.5
      "Possible match"
    else
      "Related"
    end
  end
end
