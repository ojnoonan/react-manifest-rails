require "react_manifest"

ReactManifest.configure do |config|
  # Directory under Rails.root that contains your ux source tree
  config.ux_root = "app/assets/javascripts/ux"

  # Sub-directory within ux_root that holds per-controller bundles
  config.app_dir = "app"

  # Where generated ux_*.js manifests are written (relative to Rails.root)
  config.output_dir = "app/assets/javascripts"

  # Name of the shared bundle (everything outside app/)
  config.shared_bundle = "ux_shared"

  # Always include these additional bundles on every React page (e.g. a global nav bundle)
  config.always_include = []

  # Top-level dirs inside ux_root to ignore entirely
  config.ignore = []

  # Top-level dirs in the asset pipeline to exclude from ux classification
  config.exclude_paths = ["react", "react_dev", "vendor"]

  # Warn about bundles larger than this (KB, post-gzip)
  config.size_threshold_kb = 500

  config.dry_run = false
  config.verbose = false
end
