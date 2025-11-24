# rubocop:disable Rails/SaveBang
#
class FetchRecords
  SELF_TEXT_FILE = Rails.root.join("data/CN2025_SelfText_EN_DE_FR.csv").freeze

  NON_COMMODITY_CODE_REGEX = /\A\d{2,4}\z/

  ALL_GOODS_NOMENCLATURES = CSV.parse(
    File.read(SELF_TEXT_FILE, mode: "rb:UTF-8").gsub(/\r?\n/, "\r\n"),
    headers: true,
  ).each_with_object([]) { |row, acc|
    commodity_code = row[0]
    row[1].split(" ").join("")
    description = row[2]
    goods_nomenclature_item_id = commodity_code[0..9]
    pls = commodity_code[-2..]
    next if pls != "80" # Skips sections, only

    acc << {
      goods_nomenclature_item_id: "#{goods_nomenclature_item_id}-#{pls}",
      description: description,
    }
  }.freeze

  COMMODITIES = ALL_GOODS_NOMENCLATURES.each_with_object([]) do |entry, acc|
    commodity_code = entry[:goods_nomenclature_item_id]
    goods_nomenclature_item_id, = commodity_code.split("-")
    next if goods_nomenclature_item_id.match?(NON_COMMODITY_CODE_REGEX) # Skkips headings and chapters

    acc << {
      goods_nomenclature_item_id: goods_nomenclature_item_id,
      description: entry[:description], # Fixed typo assuming intent
    }
  end

  BATCH_SIZE = 10

  class << self
    def call
      instrument do
        new.call
      end
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info "Labelling commodities took #{duration.round(2)} seconds"
    end
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
    results = []
    queue = Queue.new

    COMMODITIES.each_slice(BATCH_SIZE) { |batch| queue << batch }

    num_workers = 5

    # Enqueue nil sentinels to signal workers to exit
    num_workers.times { queue << nil }

    # Start worker threads
    workers = num_workers.times.map do
      Thread.new do
        while (batch = queue.pop)
          next unless batch # Skip if nil (exit signal)

          result = label_commodities(batch)
          mutex.synchronize do
            progress.increment
            results << result if result
          end
        end
      end
    end

    workers.each(&:join)
    results.compact.flatten
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
end
# rubocop:enable Rails/SaveBang
