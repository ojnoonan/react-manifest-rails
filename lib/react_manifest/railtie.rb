require "rails/railtie"

module ReactManifest
  class Railtie < Rails::Railtie
    # Expose config as Rails.application.config.react_manifest
    config.react_manifest = ReactManifest.configuration

    # ----------------------------------------------------------------
    # Start the file watcher in development
    # ----------------------------------------------------------------
    initializer "react_manifest.start_watcher" do
      if Rails.env.development? && !ReactManifest::Watcher.running?
        begin
          ReactManifest::Watcher.start(ReactManifest.configuration)
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
