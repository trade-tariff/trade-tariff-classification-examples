# frozen_string_literal: true

namespace :solid_queue do
  desc "Clear all jobs from Solid Queue"
  task clear: :environment do
    puts "Clearing all Solid Queue jobs..."
    SolidQueue::Job.destroy_all
    puts "Solid Queue jobs cleared."
  end

  desc "Print statistics about Solid Queue"
  task stats: :environment do
    puts "Solid Queue Statistics"
    puts "======================"
    puts
    puts "Processes"
    puts "---------"
    processes = SolidQueue::Process.all
    if processes.any?
      processes.each do |process|
        metadata = process.metadata

        if process.kind == "Worker"
          threads = metadata.fetch("thread_pool_size", "N/A")
          queues = metadata.fetch("queues", "N/A")
          puts "- Process #{process.id} (PID: #{process.pid}, Kind: #{process.kind}): #{threads} threads, processing '#{queues}' queues."
        else
          puts "- Process #{process.id} (PID: #{process.pid}, Kind: #{process.kind})"
        end
      end
    else
      puts "No running processes."
    end
    puts

    puts "Queues"
    puts "------"
    queue_names = SolidQueue::Job.distinct.pluck(:queue_name)
    queue_names.each do |queue_name|
      puts "- #{queue_name}:"
      puts "  - Jobs: #{SolidQueue::Job.where(queue_name: queue_name).count}"
      puts "  - Ready: #{SolidQueue::ReadyExecution.joins(:job).where(solid_queue_jobs: { queue_name: queue_name }).count}"
      puts "  - Claimed: #{SolidQueue::ClaimedExecution.joins(:job).where(solid_queue_jobs: { queue_name: queue_name }).count}"
      puts "  - Failed: #{SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { queue_name: queue_name }).count}"
      finished_jobs = SolidQueue::Job.where(queue_name: queue_name).where.not(finished_at: nil)
      puts "  - Finished: #{finished_jobs.count}"
      next unless finished_jobs.any?

      durations = finished_jobs.includes(:claimed_execution).map { |job|
        next unless job.claimed_execution

        job.finished_at - job.claimed_execution.created_at
      }.compact

      if durations.any?
        average_time = durations.sum / durations.size
        puts "  - Average execution time: #{average_time.round(2)}s"
      end
    end
  end

  desc "Watch Solid Queue statistics, refreshing every 5 seconds"
  task watch: :environment do
    loop do
      system("clear") || system("cls")
      Rake::Task["solid_queue:stats"].invoke
      Rake::Task["solid_queue:stats"].reenable # Allow the task to be run again
      puts "\nLast updated: #{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')}"
      sleep 5
    end
  end
end
