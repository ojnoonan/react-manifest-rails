module ReactManifest
  # Watches the ux/ directory tree for file changes and triggers
  # manifest regeneration automatically.
  #
  # Uses the `listen` gem (soft dependency — degrades gracefully if not available).
  # Auto-started in development via the Railtie initializer.
  #
  # Watches ux_root recursively so newly added controller directories are
  # picked up without a server restart.
  #
  # File-change callbacks are debounced by the listen gem and handled on a
  # background thread. Rapid back-to-back changes are coalesced: if a
  # regeneration is already in progress when a new change arrives, only one
  # additional regeneration is queued (not one per file event).
  module Watcher
    DEBOUNCE_SECONDS = 0.3
    BRANCH_SWITCH_COOLDOWN = 3

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

        @regen_mutex = Mutex.new
        @git_dir = detect_git_dir
        @last_git_head = read_git_head
        @branch_switch_until = nil

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
        @regen_thread&.join(5)
        @regen_thread = nil
      end

      def running?
        !@listener.nil?
      end

      # Kill the background regen thread and reset all regen state.
      # Intended for use in tests only.
      def reset_regen_state!
        thread = @regen_thread
        if thread&.alive?
          thread.kill
          thread.join(1)
        end
        @regen_thread  = nil
        @regen_pending = false
        @regen_mutex   = nil
        @git_dir       = nil
        @last_git_head = nil
        @branch_switch_until = nil
      end

      private

      def handle_file_changes(modified, added, removed, config)
        if branch_switch_detected?
          log_info "Branch change detected — skipping regeneration"
          return
        end

        (modified + added + removed).each { |f| Scanner.invalidate(f) }
        schedule_regeneration(config)
      end

      def branch_switch_detected?
        return false unless @git_dir

        return true if @branch_switch_until && Time.now < @branch_switch_until

        current_head = read_git_head
        return false unless current_head && @last_git_head

        if current_head != @last_git_head
          @last_git_head = current_head
          @branch_switch_until = Time.now + BRANCH_SWITCH_COOLDOWN
          return true
        end

        false
      end

      def detect_git_dir
        git_path = File.join(Rails.root.to_s, ".git")
        if File.file?(git_path)
          content = File.read(git_path).strip
          return content.sub("gitdir: ", "").strip if content.start_with?("gitdir: ")
        elsif File.directory?(git_path)
          return git_path
        end
        nil
      rescue StandardError
        nil
      end

      def read_git_head
        return nil unless @git_dir

        File.read(File.join(@git_dir, "HEAD")).strip
      rescue StandardError
        nil
      end

      # Schedule a regeneration on the background thread. Coalesces rapid
      # back-to-back file events: if the regen thread is already running,
      # we just set @regen_pending and return immediately so the listen
      # callback is never blocked.
      def schedule_regeneration(config)
        @regen_mutex ||= Mutex.new
        mutex = @regen_mutex
        mutex.synchronize do
          @regen_pending = true
          return if @regen_thread&.alive?

          @regen_thread = Thread.new { regen_loop(config, mutex) }
        end
      end

      # Background thread: regenerate, then check whether another change
      # arrived while we were busy. If so, regenerate again; otherwise exit.
      def regen_loop(config, mutex)
        loop do
          mutex.synchronize { @regen_pending = false }
          regenerate!(config)
          still_pending = mutex.synchronize { @regen_pending }
          break unless still_pending
        end
      end

      def regenerate!(config)
        results = Generator.new(config).run!
        written = results.count { |r| r[:status] == :written }
        log_info "#{written} manifest(s) written" if written.positive?
      rescue StandardError => e
        log_warn "Error during regeneration: #{e.message}"
        log_debug e.backtrace.first(5).join("\n") if config.verbose?
      end
    end
  end
end
