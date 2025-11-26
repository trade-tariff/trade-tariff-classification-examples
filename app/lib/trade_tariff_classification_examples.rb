# frozen_string_literal: true

module TradeTariffClassificationExamples
  class << self
    def ai_client
      @ai_client ||= case ENV.fetch("AI_CLIENT", "openai")
                     when "openai"
                       OpenaiClient
                     when "gemini_shell"
                       GeminiShellClient
                     end
    end

    def govuk_app_domain
      @govuk_app_domain ||= ENV.fetch(
        "GOVUK_APP_DOMAIN",
        "https://localhost:3006",
      )
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

    def server_namespace
      @server_namespace ||= ENV.fetch("SERVER_NAMESPACE", "classification")
    end

    def search_client
      @search_client ||= SearchClient.new(
        opensearch_client,
        indexes: search_indexes,
      )
    end

    def opensearch_client
      @opensearch_client ||= OpenSearch::Client.new(opensearch_configuration)
    end

    def batch_size
      ENV.fetch("BATCH_LABEL_SIZE", 10).to_i
    end

    def search_indexes
      [
        CommodityIndex.new,
      ]
    end

    def fpo_search_api_key
      @fpo_search_api_key ||= ENV["FPO_SEARCH_API_KEY"]
    end

    def openai_api_key
      @openai_api_key ||= ENV["OPENAI_API_KEY"]
    end

    def openai_user
      @openai_user ||= ENV["OPENAI_USER"]
    end

    def interactive_search_max_attempts
      @interactive_search_max_attempts ||= ENV.fetch("INTERACTIVE_SEARCH_MAX_ATTEMPTS", 2).to_i
    end

  private

    def opensearch_configuration
      {
        host: opensearch_url,
        log: opensearch_debug,
      }
    end

    def opensearch_url
      ENV.fetch("OPENSEARCH_URL", "http://host.docker.internal:9200")
    end

    def opensearch_debug
      ENV.fetch("OPENSEARCH_DEBUG", "false") == "true"
    end
  end
end
