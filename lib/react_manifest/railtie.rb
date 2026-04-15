require "rails/railtie"

module ReactManifest
  class Railtie < Rails::Railtie
    # ----------------------------------------------------------------
    # In development, generate once on boot if expected manifests are missing.
    # This makes first-run setup deterministic even before any file change event.
    # ----------------------------------------------------------------
    initializer "react_manifest.ensure_manifests" do
      next unless Rails.env.development?

      config = ReactManifest.configuration
      # Private class method: call via send from the initializer instance context.
      missing = self.class.send(:missing_manifest_bundles, config)
      next if missing.empty?

      message = "[ReactManifest] Missing manifests on boot: #{missing.join(', ')}. Generating now..."
      Rails.logger&.info(message)
      $stdout.puts(message) if config.stdout_logging?

      begin
        results = ReactManifest::Generator.new(config).run!
        written = results.count { |r| r[:status] == :written }
        unchanged = results.count { |r| r[:status] == :unchanged }
        done = "[ReactManifest] Boot generation complete: #{written} written, #{unchanged} unchanged"
        Rails.logger&.info(done)
        $stdout.puts(done) if config.stdout_logging?
      rescue StandardError => e
        error = "[ReactManifest] Could not generate manifests on boot: #{e.message}"
        Rails.logger&.warn(error)
        $stdout.puts(error) if config.stdout_logging?
      end
    end

    # Expose config as Rails.application.config.react_manifest
    config.react_manifest = ReactManifest.configuration

    # ----------------------------------------------------------------
    # Start the file watcher in development
    # ----------------------------------------------------------------
    initializer "react_manifest.start_watcher" do
      if Rails.env.development? && !ReactManifest::Watcher.running?
        begin
          ReactManifest::Watcher.start(ReactManifest.configuration)
          Rails.logger&.info("[ReactManifest] Development watcher is active") if ReactManifest.configuration.verbose?
        rescue StandardError => e
          Rails.logger.warn "[ReactManifest] Could not start file watcher: #{e.message}"
        end
      end
    end

    # ----------------------------------------------------------------
    # Include react_bundle_tag in all ActionView templates
    # ----------------------------------------------------------------
    initializer "react_manifest.view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include ReactManifest::ViewHelpers
      end
    end

    # ----------------------------------------------------------------
    # Hook manifest generation into assets:precompile
    # (safety net for CI/production — dev uses the watcher)
    #
    # Using prepend_actions so generation runs as a block before
    # Sprockets begins compiling, rather than as a Rake prerequisite
    # (which is subject to parallel task ordering under rake -j).
    # ----------------------------------------------------------------
    rake_tasks do
      load File.expand_path("../../tasks/react_manifest.rake", __dir__)

      if Rake::Task.task_defined?("assets:precompile")
        Rake::Task["assets:precompile"].enhance(["react_manifest:generate"])
      end
    end

    class << self
      private

      def missing_manifest_bundles(config)
        output_dir = config.abs_output_dir
        expected_manifest_bundles(config).reject do |bundle_name|
          File.exist?(File.join(output_dir, "#{bundle_name}.js"))
        end
      end

      def expected_manifest_bundles(config)
        classification = ReactManifest::TreeClassifier.new(config).classify
        ([config.shared_bundle] + classification.controller_dirs.map { |ctrl| ctrl[:bundle_name] }).uniq
      end
    end
  end
end
