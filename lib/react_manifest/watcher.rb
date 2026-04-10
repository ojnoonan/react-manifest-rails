require "listen"

module ReactManifest
  # Watches the ux/ directory tree for file changes and triggers
  # manifest regeneration automatically.
  #
  # Uses the `listen` gem (hard dependency). Auto-started in development
  # via the Railtie initializer.
  module Watcher
    DEBOUNCE_SECONDS = 0.3

    class << self
      def start(config = ReactManifest.configuration)
        classifier = TreeClassifier.new(config)
        dirs = classifier.watched_dirs

        if dirs.empty?
          log "No directories to watch. Check ux_root: #{config.ux_root}"
          return
        end

        log "Watching #{dirs.size} director#{dirs.size == 1 ? 'y' : 'ies'} for changes..."
        dirs.each { |d| log "  #{d.sub(Rails.root.to_s + '/', '')}" } if config.verbose?

        @listener = Listen.to(
          *dirs,
          only:    /\.(js|jsx)$/,
          latency: DEBOUNCE_SECONDS
        ) do |modified, added, removed|
          changed = (modified + added + removed).map { |f| File.basename(f) }
          log "File change detected: #{changed.join(', ')}"
          regenerate!(config)
        end

        @listener.start
      end

      def stop
        @listener&.stop
        @listener = nil
      end

      def running?
        !@listener.nil?
      end

      private

      def regenerate!(config)
        Generator.new(config).run!
        log "Manifests regenerated"
      rescue => e
        log "Error during regeneration: #{e.message}"
        log e.backtrace.first(5).join("\n") if config.verbose?
      end

      def log(message)
        msg = "[ReactManifest] #{message}"
        if defined?(Rails) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts msg
        end
      end
    end
  end
end
