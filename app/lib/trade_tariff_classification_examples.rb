# frozen_string_literal: true

module TradeTariffClassificationExamples
  class << self
    def govuk_app_domain
      @govuk_app_domain ||= ENV.fetch(
        "GOVUK_APP_DOMAIN",
        "https://localhost:3006",
      )
    end

    def elasticsearch_url
      ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200")
    end

    def cors_host
      ENV.fetch("GOVUK_APP_DOMAIN", "*").sub(%r{https?://}, "")
    end

    def revision
      @revision ||= `cat REVISION 2>/dev/null || echo 'development'`.strip
    end

    def uk_backend_url
      @uk_backend_url ||= ENV["UK_BACKEND_URL"]
    end

    def basic_session_password
      @basic_session_password ||= ENV["BASIC_PASSWORD"]
    end
  end
end
