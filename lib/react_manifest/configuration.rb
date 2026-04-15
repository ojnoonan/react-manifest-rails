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

    # Subdirectory under output_dir that holds generated ux_*.js manifests.
    # Keeping generated files out of output_dir root avoids clutter.
    attr_accessor :manifest_subdir

    # Bundle name for auto-generated shared bundle (all non-app/ dirs)
    attr_accessor :shared_bundle

    # Bundles always prepended by react_bundle_tag (e.g. ["ux_main"])
    attr_accessor :always_include

    # Controller directory names directly under ux_root/app_dir to skip entirely.
    # Example: ignore = ["admin"] skips ux/app/admin/* when building ux_<controller>.js.
    attr_accessor :ignore

    # Path segments to exclude while scanning files under ux_root.
    # This is segment matching (not full path matching), so "vendor" excludes
    # ux/vendor/foo.js and ux/app/users/vendor/bar.jsx, but not ux/vendor_custom/x.js.
    # These are not application.js includes; they only affect ux tree scanning.
    attr_accessor :exclude_paths

    # Warn if a bundle exceeds this size in KB (0 = disabled)
    attr_accessor :size_threshold_kb

    # File extensions to scan (default: js and jsx; add "ts", "tsx" for TypeScript)
    attr_accessor :extensions

    # Preview mode: print what would change, write nothing.
    # Applies anywhere generation runs (manual task, boot sync, watcher).
    attr_accessor :dry_run

    # Extra diagnostic logging (summary lines and richer error context).
    attr_accessor :verbose

    # Emit ReactManifest status lines to stdout in development.
    # Independent from Rails.logger output.
    attr_accessor :stdout_logging

    def initialize
      @ux_root           = "app/assets/javascripts/ux"
      @app_dir           = "app"
      @output_dir        = "app/assets/javascripts"
      @manifest_subdir   = "ux_manifests"
      @shared_bundle     = "ux_shared"
      @always_include    = []
      @ignore            = []
      @exclude_paths     = %w[react react_dev vendor]
      @size_threshold_kb = 500
      @extensions        = %w[js jsx]
      @dry_run           = false
      @verbose           = false
      @stdout_logging    = true
    end

    def dry_run?
      !!@dry_run
    end

    def verbose?
      !!@verbose
    end

    def stdout_logging?
      !!@stdout_logging
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

    def abs_manifest_dir
      subdir = normalized_manifest_subdir
      return abs_output_dir if subdir.empty?

      File.join(abs_output_dir, subdir)
    end

    def normalized_manifest_subdir
      manifest_subdir.to_s.gsub(%r{\A/+|/+\z}, "")
    end
  end
end
