module ReactManifest
  # Holds all configuration for the gem. Obtain via {ReactManifest.configure}.
  #
  # @example
  #   ReactManifest.configure do |c|
  #     c.ux_root           = "app/assets/javascripts/ux"
  #     c.extensions        = %w[js jsx ts tsx]
  #     c.size_threshold_kb = 1000
  #   end
  class Configuration
    # Root of the ux/ tree to scan (relative to Rails.root)
    attr_accessor :ux_root

    # Subdir within ux_root that contains per-controller JSX
    attr_accessor :app_dir

    # Where generated ux_*.js manifests are written (relative to Rails.root)
    attr_accessor :output_dir

    # Bundle name for auto-generated shared bundle (all non-app/ dirs)
    attr_accessor :shared_bundle

    # Bundles always prepended by react_bundle_tag (e.g. ["ux_main"])
    attr_accessor :always_include

    # Directories under app_dir to completely ignore
    attr_accessor :ignore

    # Top-level dirs under output_dir to never scan (vendor libs, etc.)
    attr_accessor :exclude_paths

    # Warn if a bundle exceeds this size in KB (0 = disabled)
    attr_accessor :size_threshold_kb

    # File extensions to scan (default: js and jsx; add "ts", "tsx" for TypeScript)
    attr_accessor :extensions

    # Print what would change, write nothing
    attr_accessor :dry_run

    # Extra logging
    attr_accessor :verbose

    def initialize
      @ux_root           = "app/assets/javascripts/ux"
      @app_dir           = "app"
      @output_dir        = "app/assets/javascripts"
      @shared_bundle     = "ux_shared"
      @always_include    = []
      @ignore            = []
      @exclude_paths     = %w[react react_dev vendor]
      @size_threshold_kb = 500
      @extensions        = %w[js jsx]
      @dry_run           = false
      @verbose           = false
    end

    def dry_run?
      !!@dry_run
    end

    def verbose?
      !!@verbose
    end

    # Glob fragment used by Dir.glob, e.g. "*.{js,jsx}" or "*.{js,jsx,ts,tsx}"
    def extensions_glob
      "*.{#{extensions.join(',')}}"
    end

    # Regexp used by the file watcher to filter events, e.g. /\.(js|jsx)$/
    def extensions_pattern
      Regexp.new("\\.(#{extensions.map { |e| Regexp.escape(e) }.join('|')})$")
    end

    # Absolute path helpers (requires Rails.root to be set)
    def abs_ux_root
      Rails.root.join(ux_root).to_s
    end

    def abs_app_dir
      File.join(abs_ux_root, app_dir)
    end

    def abs_output_dir
      Rails.root.join(output_dir).to_s
    end
  end
end
