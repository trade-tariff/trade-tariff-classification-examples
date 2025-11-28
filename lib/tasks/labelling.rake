# frozen_string_literal: true

namespace :labelling do
  desc "Label commodities in batches"
  task :batch_label, [:dry_run] => :environment do |_, args|
    BatchLabelCommodities.call(dry_run: args[:dry_run] == "true")
  end

  desc "Label missing commodities from the trade tariff"
  task :missing_commodities, [:dry_run] => :environment do |_, args|
    LabelMissingCommodities.call(dry_run: args[:dry_run] == "true")
  end
end
