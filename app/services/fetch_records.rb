# rubocop:disable Rails/SaveBang
class FetchRecords
  COMMODITIES_FILE = Rails.root.join("data/CN2025_SelfText_EN_DE_FR.csv").freeze
  COMMODITY_CODE_REGEX = /\A\d{6,8}\z/

  COMMODITIES = CSV.parse(
    File.read(COMMODITIES_FILE, mode: "rb:UTF-8").gsub(/\r?\n/, "\r\n"),
    headers: true,
  ).each_with_object([]) { |row, acc|
    commodity_code = row[0]
    cn_code = row[1].split(" ").join("")
    description = row[2]
    pls = commodity_code[-2..]

    next unless cn_code.match?(COMMODITY_CODE_REGEX)
    next if pls != "80"

    acc << {
      goods_nomenclature_item_id: commodity_code[0..9],
      description: description,
    }
  }.freeze

  BATCH_SIZE = 100

  def initialize(client = build_client)
    @client = client
  end

  def call
    Thread.abort_on_exception = true

    total_batches = (COMMODITIES.size.to_f / BATCH_SIZE).ceil
    progress = ProgressBar.create(
      total: total_batches,
      format: "%a %B %p%% %r batches/min %t",
      title: "Processing batches",
    )
    mutex = Mutex.new

    threads = COMMODITIES.each_slice(BATCH_SIZE).map do |batch|
      Thread.new do
        result = label_commodities(batch)
        mutex.synchronize { progress.increment }
        result # Return for later collection via thread.value
      end
    end

    threads.each(&:join)
    threads.map(&:value).compact.flatten
  end

private

  def label_commodities(batch)
    LabelCommodities.new(batch).call
  rescue StandardError => e
    Rails.logger.info "Error processing batch: #{e.message} - trying again"

    begin
      LabelCommodity.new(batch).call
    rescue StandardError => e
      Rails.logger.error "Failed to process batch after retry: #{e.message}"
      Rails.logger.info e.backtrace.join("\n")
      Rails.logger.info "Skipping this batch."
      Rails.logger.info batch.to_json

      nil
    end
  end

  def commodities
    @commodities ||= COMMODITIES.each_with_object([]) do |commodity_code, acc|
      response = @client.get("/uk/api/commodities/#{commodity_code}")
      result = TariffJsonapiParser.new(response.body).parse

      next unless result.is_a?(Hashie::Mash)

      description = "#{result.ancestors.map(&:description).join(' > ')} > #{result.description}"

      acc << {
        goods_nomenclature_item_id: result.goods_nomenclature_item_id,
        description: description,
      }
    end
  end

  def build_client
    Faraday.new(url: "https://staging.trade-tariff.service.gov.uk") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers["Accept"] = "application/vnd.hmrc.2.0+json"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["User-Agent"] = "TradeTariffClassificationExamples/#{TradeTariffClassificationExamples.revision}"
      faraday.response :json, content_type: /\bjson$/
    end
  end
end
# rubocop:enable Rails/SaveBang
