# frozen_string_literal: true

class AuthenticatedController < ApplicationController
  include BasicSessionAuth
end
