# frozen_string_literal: true

class SearchCommodity
  include ActiveModel::Model

  attr_accessor :query

  validates :query, presence: true

  def persisted?
    false
  end

  def results
    []
  end
end
