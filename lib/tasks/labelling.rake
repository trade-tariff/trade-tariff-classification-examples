# frozen_string_literal: true

namespace :labelling do
  desc "Label commodities in batches"
  task :batch_label, [:dry_run] => :environment do |_, args|
    BatchLabelCommodities.call(dry_run: args[:dry_run] == "true")
  end
end
