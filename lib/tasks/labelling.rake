# frozen_string_literal: true

namespace :labelling do
  desc "Label commodities in batches"
  task batch_label: :environment do
    BatchLabelCommodities.call
  end
end
