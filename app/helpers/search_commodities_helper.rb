module SearchCommoditiesHelper
  def questions_for(search_type, form)
    return unless search_type.interactive?

    if form.object.questions.present?
      question_radios = form.object.questions.map do |question|
        if question.answer.present?
          form.hidden_field "question_#{question.index}", value: question.answer
        else
          form.govuk_collection_radio_buttons(
            "question_#{question.index}",
            question.question_options,
            :id,
            :name,
            class: question.answer.present? ? "answered" : "",
            legend: { text: question.text, size: "m" },
            hint: { text: "" },
            include_hidden: true,
            form_group: { id: "search-commodity-question-#{question.index}-field-error" },
          )
        end
      end
      safe_join(question_radios)
    end
  end

  def render_commodity_accordion(results, max_score)
    govuk_accordion do |accordion|
      results.each_with_index do |commodity, index|
        confidence = commodity_confidence(commodity, max_score)
        url = "https://trade-tariff.service.gov.uk/commodities/#{commodity.commodity_code}"
        summary_html = content_tag(:span) do
          content_tag(:span, confidence, class: "confidence")
        end

        accordion.with_section(
          heading_text: commodity.original_description || commodity.description,
          summary_text: summary_html,
          expanded: index.zero?,
        ) do
          govuk_button_link_to("Select", url, class: "govuk-!-float-right", target: "_blank", rel: "noopener") +
            govuk_summary_list do |summary_list|
              highlighted_desc = if commodity.respond_to?(:highlight) && commodity.highlight&.key?(:searchable_description)
                                   commodity.highlight[:searchable_description].join(" ... ").html_safe
                                 else
                                   commodity.description
                                 end
              summary_list.with_row do |row|
                row.with_key(text: "Description")
                row.with_value { highlighted_desc }
              end

              if commodity.known_brands.present?
                summary_list.with_row do |row|
                  row.with_key(text: "Known brands")
                  row.with_value(text: commodity.known_brands.join(", "))
                end
              end

              if commodity.colloquial_terms.present?
                summary_list.with_row do |row|
                  row.with_key(text: "Colloquial terms")
                  row.with_value(text: commodity.colloquial_terms.join(", "))
                end
              end

              if commodity.synonyms.present?
                summary_list.with_row do |row|
                  row.with_key(text: "Synonyms")
                  row.with_value(text: commodity.synonyms.join(", "))
                end
              end
            end
        end
      end
    end
  end

private

  def commodity_confidence(commodity, max_score)
    text = if commodity.confidence.present?
             "#{commodity.confidence.to_s.upcase} AI confidence"
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
