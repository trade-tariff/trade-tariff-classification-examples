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

    puts "Global Stats"
    puts "------------"
    claimed_executions = SolidQueue::ClaimedExecution.all
    if claimed_executions.any?
      durations = claimed_executions.map { |execution| Time.zone.now - execution.created_at }
      average_time = durations.sum / durations.size
      puts "- Average time of running jobs: #{average_time.round(2)}s"
    else
      puts "- No jobs are currently running."
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
    end
    puts

    puts "Queue State Legend"
    puts "------------------"
    puts "- Jobs: Total number of jobs in the queue."
    puts "- Ready: Jobs waiting to be picked up by a worker."
    puts "- Claimed: Jobs currently being processed by a worker."
    puts "- Failed: Jobs that have failed."
    puts "- Finished: Jobs that have completed successfully."
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

  desc "Retry all failed jobs"
  task retry_failed: :environment do
    SolidQueue::FailedExecution.all.find_each do |failed_execution|
      Rails.logger.info "Retrying job #{failed_execution.job_id}"
      failed_execution.retry
    end
  end

  desc "Debug failed jobs"
  task debug_failed: :environment do
    puts "Failed Job Debugger"
    puts "==================="
    puts

    failed_executions = SolidQueue::FailedExecution.all

    if failed_executions.any?
      failed_executions.each do |failed_execution|
        job = failed_execution.job

        puts "--------------------------------------------------"
        puts "Job ID: #{job.id}"
        puts "Arguments: #{job.arguments.inspect}"
        puts "Error: #{failed_execution.error['class']}"
        puts "Message: #{failed_execution.error['message']}"
        puts "Backtrace:"
        puts failed_execution.error["backtrace"].first(5).join("\n")
        puts "--------------------------------------------------"
        puts
      end
    else
      puts "No failed jobs found."
    end
  end
end
