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
      include ReactManifest::Logging

      def start(config = ReactManifest.configuration)
        begin
          require "listen"
        rescue LoadError
          log_warn "listen gem not available — file watching disabled. " \
                   "Add `gem 'listen'` to the development group in your Gemfile."
          return
        end

        root = config.abs_ux_root

        unless Dir.exist?(root)
          log_warn "ux_root does not exist (#{root}) — file watching disabled until directory is created."
          return
        end

        log_info "Watching #{root.sub("#{Rails.root}/", '')} for changes..."

        @listener = Listen.to(
          root,
          only: config.extensions_pattern,
          latency: DEBOUNCE_SECONDS
        ) do |modified, added, removed|
          changed = (modified + added + removed).map { |f| File.basename(f) }
          log_info "File change detected: #{changed.join(', ')}"
          handle_file_changes(modified, added, removed, config)
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

      def handle_file_changes(modified, added, removed, config)
        (modified + added + removed).each { |f| Scanner.invalidate(f) }
        regenerate!(config)
      end

      def regenerate!(config)
        Generator.new(config).run!
        log_info "Manifests regenerated"
      rescue StandardError => e
        log_warn "Error during regeneration: #{e.message}"
        log_debug e.backtrace.first(5).join("\n") if config.verbose?
      end
    end
  end
end
