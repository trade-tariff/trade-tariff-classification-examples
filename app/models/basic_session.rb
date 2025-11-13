# frozen_string_literal: true

class BasicSession
  include ActiveModel::Model

  attr_accessor :return_url, :password

  validates :return_url, presence: true
  validates :password, inclusion: { in: [TradeTariffClassificationExamples.basic_session_password] }
end
