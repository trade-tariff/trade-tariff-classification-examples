require "open3"

class GeminiShellClient
  MODEL = "gemini-2.5-pro".freeze

  def self.call(context, model: MODEL)
    instrument do
      new.call(context, model: model)
    end
  end

  def call(context, model: MODEL)
    command = [
      "gemini",
      "-m #{model}",
      "-p #{context.inspect}",
      "-s",
    ]

    stdout, stderr, status = Open3.capture3(command.join(" "))

    if status.success?
      stdout.strip.gsub("```json", "").gsub("```", "").strip
    else
      Rails.logger.error "GeminiShellClient error: #{stderr}"
      ""
    end
  end

  def self.instrument
    start_time = Time.zone.now
    yield
  ensure
    end_time = Time.zone.now
    duration = end_time - start_time
    Rails.logger.info "GeminiShellClient call took #{duration.round(2)} seconds"
  end
end
