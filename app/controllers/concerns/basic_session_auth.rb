# frozen_string_literal: true

module BasicSessionAuth
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication

    def require_authentication
      return if session[:authenticated]

      redirect_to new_basic_session_path(return_url: request.fullpath)
    end
  end
end
