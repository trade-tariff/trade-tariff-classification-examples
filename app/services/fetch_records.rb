# rubocop:disable Rails/SaveBang
class FetchRecords
  SELF_TEXT_FILE = Rails.root.join("data/CN2025_SelfText_EN_DE_FR.csv").freeze
  NON_COMMODITY_CODE_REGEX = /\A\d{2,4}(0{6,8})?\z/

  ALL_GOODS_NOMENCLATURES = CSV.parse(
    File.read(SELF_TEXT_FILE, mode: "rb:UTF-8").gsub(/\r?\n/, "\r\n"),
    headers: true,
  ).each_with_object([]) { |row, acc|
    commodity_code = row[0]
    row[1].split(" ").join("")
    description = row[2]
    goods_nomenclature_item_id = commodity_code[0..9]
    pls = commodity_code[-2..]

    acc << {
      goods_nomenclature_item_id: "#{goods_nomenclature_item_id}-#{pls}",
      description: description,
    }
  }.freeze

  INITIAL_COMMODITIES = File.read(Rails.root.join("data/initial.csv"))

  COMMODITIES = ALL_GOODS_NOMENCLATURES.each_with_object([]) do |entry, acc|
    commodity_code = entry[:goods_nomenclature_item_id]
    goods_nomenclature_item_id, pls = commodity_code.split("-")

    next if goods_nomenclature_item_id.match?(NON_COMMODITY_CODE_REGEX)
    next if pls != "80"

    next unless INITIAL_COMMODITIES.include?(goods_nomenclature_item_id)

    acc << {
      goods_nomenclature_item_id: goods_nomenclature_item_id,
      description: entry[:description],
    }
  end

  BATCH_SIZE = 10

  class << self
    def call(client = nil)
      instrument { new(client).call }
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "FetchRecords call took #{duration.round(2)} seconds"
    end
  end

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
        result
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
      LabelCommodities.new(batch).call
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
