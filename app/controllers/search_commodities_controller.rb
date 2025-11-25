class SearchCommoditiesController < ApplicationController
  def show
    search_commodity
    search_commodity.valid? if query?
    results

    render :search
  end

private

  def results
    @results ||= if respond_to?("#{search_type}_results", true)
                   send("#{search_type}_results")
                 else
                   flash.now[:alert] = "Unknown search type: #{search_type}"
                   []
                 end
  end

  def interactive_results
    return [] unless query?

    if @search_commodity.unanswered_questions.any?
      @search_commodity.validate_answers
      return short_list
    end

    @interactive_memory = InteractiveSearch.new(interactive_memory).call
    @search_commodity.assign_questions(@interactive_memory.questions)

    unless @search_commodity.save
      flash.now[:alert] = "Encountered an error saving your answers. Please try again."
      return short_list
    end

    return short_list unless @interactive_memory.final_answer?

    @interactive_memory.final_commodities
  end

  def non_interactive_results
    if query?
      NonInteractiveSearch.new(query).call
    else
      []
    end
  end

  def neural_net_results
    if query?
      NeuralNetSearch.new(query).call
    else
      []
    end
  end

  def classic_results
    if query?
      ClassicSearch.new(query).call
    else
      []
    end
  end

  def search_commodity
    @search_commodity ||= if query?
                            SearchCommodity.build(params, session)
                          else
                            SearchCommodity.clear_session(session)
                            SearchCommodity.new
                          end
  end

  def query?
    query.present?
  end

  def query
    @query ||= params.dig(:search_commodity, :query)
  end

  def max_score
    @max_score ||= results.map(&:score).max.to_f
  end

  def search_type
    type = params[:search_type] || search_commodity.search_type || "interactive"
    ActiveSupport::StringInquirer.new(type)
  end

  def interactive_memory
    InteractiveMemory.new(
      search_input: query,
      opensearch_answers: non_interactive_results,
      questions: search_commodity.questions,
    )
  end

  def short_list
    interactive_memory.opensearch_answers.sort_by { |c| -c.score }.first(10)
  end

  helper_method :results,
                :max_score,
                :search_type,
                :interactive_memory,
                :search_commodity
end
