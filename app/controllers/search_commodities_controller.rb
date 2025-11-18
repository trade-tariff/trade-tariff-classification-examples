class SearchCommoditiesController < ApplicationController
  EARLY_RESULT_COUNT = 1

  before_action :search_commodity

  def show
    search_commodity.valid? if query?

    render :search
  end

private

  def show_result?
    results.size == EARLY_RESULT_COUNT
  end

  def elasticsearch_results
    []
  end

  def search_commodity
    @search_commodity ||= if query?
                            SearchCommodity.new(search_commodity_params)
                          else
                            SearchCommodity.new
                          end
  end

  def search_commodity_params
    params.require(:search_commodity).permit(:query)
  end

  def query?
    params[:search_commodity].present?
  end

  def results
    @results ||= if query?
                   Search.new(search_commodity.query).call
                 else
                   []
                 end
  end

  def max_score
    @max_score ||= results.map(&:score).max.to_f
  end

  helper_method :results, :max_score
end
