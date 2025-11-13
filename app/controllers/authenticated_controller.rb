# frozen_string_literal: true

class AuthenticatedController < ApplicationController
  include BasicSessionAuth

  protect_from_forgery with: :exception
end
