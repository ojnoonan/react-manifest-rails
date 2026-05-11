require "rails/railtie"

module ReactManifest
  class Railtie < Rails::Railtie
    # ----------------------------------------------------------------
    # In development, always regenerate manifests on boot so that files
    # added between restarts (e.g. via git merge) are picked up immediately.
    # The generator is idempotent — it skips writes when content is unchanged.
    # ----------------------------------------------------------------
    initializer "react_manifest.ensure_manifests", after: :load_config_initializers do
      next unless Rails.env.development?

      config = ReactManifest.configuration

      begin
        results = ReactManifest::Generator.new(config).run!
        written = results.count { |r| r[:status] == :written }
        if written.positive?
          done = "[ReactManifest] Boot generation complete: #{written} written"
          Rails.logger&.info(done)
          $stdout.puts(done) if config.stdout_logging?
        end
      rescue StandardError => e
        error = "[ReactManifest] Could not generate manifests on boot: #{e.message}"
        Rails.logger&.warn(error)
        $stdout.puts(error) if config.stdout_logging?
      end
    end

    # Expose config as Rails.application.config.react_manifest
    config.react_manifest = ReactManifest.configuration

    # Keep generated manifests in a dedicated folder while preserving logical
    # asset names (ux_shared, ux_users, etc.) via an explicit Sprockets path.
    initializer "react_manifest.assets_path" do |app|
      next unless app.config.respond_to?(:assets)

      manifest_dir = ReactManifest.configuration.abs_manifest_dir
      app.config.assets.paths.delete(manifest_dir)
      app.config.assets.paths.unshift(manifest_dir)

      app.config.assets.configure do |env|
        next unless defined?(React::JSX::Processor)

        begin
          env.register_mime_type("application/jsx", extensions: [".jsx", ".js.jsx", ".es.jsx", ".es6.jsx"])
        rescue StandardError
          nil
        end

        begin
          env.register_transformer("application/jsx", "application/javascript", React::JSX::Processor)
        rescue StandardError
          nil
        end
      end
    end

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
  end
end
