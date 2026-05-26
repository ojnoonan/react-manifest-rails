module ReactManifest
  module Logging
    def log_debug(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.debug(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    def log_info(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.debug(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    def log_warn(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.warn(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    private

    def stdout_logging_needed?
      ReactManifest.configuration.stdout_logging? && !rails_console?
    end

    def rails_console?
      defined?(Rails::Console)
    end
  end
end
