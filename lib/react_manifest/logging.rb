module ReactManifest
  module Logging
    def log_debug(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.debug(full)
      $stdout.puts(full) if ReactManifest.configuration.stdout_logging?
    end

    def log_info(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.info(full)
      $stdout.puts(full) if ReactManifest.configuration.stdout_logging?
    end

    def log_warn(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.warn(full)
      $stdout.puts(full) if ReactManifest.configuration.stdout_logging?
    end
  end
end
