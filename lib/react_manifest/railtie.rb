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
        ReactManifest::Watcher.start(ReactManifest.configuration)
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
    # ----------------------------------------------------------------
    rake_tasks do
      load File.expand_path("../../../tasks/react_manifest.rake", __FILE__)

      # Only enhance if the assets task is available (sprockets-rails present)
      Rake::Task.task_defined?("assets:precompile") &&
        Rake::Task["assets:precompile"].enhance(["react_manifest:generate"])
    end
  end
end
