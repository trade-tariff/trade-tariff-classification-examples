class SearchCommoditiesController < ApplicationController
  before_action :results, :search_commodity

  def show
    search_commodity.valid? if query?

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
    if query?
      @interactive_memory = InteractiveSearch.new(interactive_memory).call
      @search_commodity.assign_questions(@interactive_memory.questions)

      if @search_commodity.save
        Rails.logger.info "SearchCommodity saved to session with questions: #{@interactive_memory.questions.map(&:as_json)}"
      else
        Rails.logger.error "Failed to save SearchCommodity to session: #{@search_commodity.errors.full_messages.join(', ')}"
      end

      if @interactive_memory.final_answer?
        @interactive_memory.final_answer
      else
        []
      end
    else
      []
    end
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
      elasticsearch_answers: non_interactive_results,
      questions: search_commodity.questions,
    )
  end

  helper_method :results, :max_score, :search_type, :interactive_memory
end
