module SearchCommoditiesHelper
  def render_commodity_accordion(results, max_score)
    govuk_accordion do |accordion|
      results.each_with_index do |commodity, index|
        confidence = commodity_confidence(commodity, max_score)
        url = "https://trade-tariff.service.gov.uk/commodities/#{commodity.commodity_code}"
        button_html = govuk_button_link_to("Select", url, class: "govuk-!-float-right", target: "_blank", rel: "noopener")
        summary_html = content_tag(:span) do
          content_tag(:span, "#{confidence}% confidence", class: "confidence") +
            " | ".html_safe +
            button_html
        end
        summary_html = content_tag(:span, summary_html, onclick: "event.stopPropagation();") if button_html.present?

        accordion.with_section(
          heading_text: commodity.original_description,
          summary_text: summary_html,
          expanded: index.zero?,
        ) do
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
    max_score.to_f.positive? ? ((commodity.score.to_f / max_score) * 100).round : 0
  end
end
