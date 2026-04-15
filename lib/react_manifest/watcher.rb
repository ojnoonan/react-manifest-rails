module ReactManifest
  # Watches the ux/ directory tree for file changes and triggers
  # manifest regeneration automatically.
  #
  # Uses the `listen` gem (soft dependency — degrades gracefully if not available).
  # Auto-started in development via the Railtie initializer.
  #
  # Watches ux_root recursively so newly added controller directories are
  # picked up without a server restart.
  module Watcher
    DEBOUNCE_SECONDS = 0.3

    class << self
      def start(config = ReactManifest.configuration)
        begin
          require "listen"
        rescue LoadError
          log "listen gem not available — file watching disabled. " \
              "Add `gem 'listen'` to the development group in your Gemfile."
          return
        end

        root = config.abs_ux_root

        unless Dir.exist?(root)
          log "ux_root does not exist (#{root}) — file watching disabled until directory is created."
          return
        end

        log "Watching #{root.sub("#{Rails.root}/", '')} for changes..."

        @listener = Listen.to(
          root,
          only: config.extensions_pattern,
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
      rescue StandardError => e
        log "Error during regeneration: #{e.message}"
        log e.backtrace.first(5).join("\n") if config.verbose?
      end

      def log(message)
        msg = "[ReactManifest] #{message}"
        if defined?(Rails) && Rails.logger
          Rails.logger.info(msg)
          $stdout.puts(msg) if Rails.env.development? && ReactManifest.configuration.stdout_logging?
        else
          $stdout.puts msg
        end
      end
    end
  end
end
