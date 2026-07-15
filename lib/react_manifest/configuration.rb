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

    # When true (default), the gem ensures the generated manifest dir is gitignored
    # (adds the entry on dev boot if missing). Set false to manage .gitignore yourself.
    attr_accessor :manage_gitignore

    # Bundle name for auto-generated shared bundle (all non-app/ dirs)
    attr_accessor :shared_bundle

    # When true (default), a component defined under app_dir but used by any other
    # bundle is emitted into the shared bundle (loaded once per page) instead of
    # being inlined into each consumer. Set false to restore legacy inlining.
    attr_accessor :auto_shared

    # Bundles always prepended by react_bundle_tag (e.g. ["ux_main"])
    attr_accessor :always_include

    # Controller directory names directly under ux_root/app_dir to skip entirely.
    # Example: ignore = ["admin"] skips ux/app/admin/* when building ux_<controller>.js.
    attr_accessor :ignore

    # Controller directory names (under ux_root/app_dir) whose files must never
    # be inlined into any OTHER controller's manifest via inferred cross-app
    # dependency detection. Their own ux_<name>.js manifest is unaffected —
    # still includes all of their own files as usual.
    #
    # Symbol usage detection is pure regex (no AST), so a generic component
    # name can collide with an unrelated word appearing as plain JSX text
    # elsewhere (e.g. a "Show" component vs a "Show More" button label in a
    # completely different controller) and get wrongly inlined everywhere.
    # Use this for self-contained dirs (e.g. a page-builder tool bundling its
    # own vendored library) that should truly never leak into other bundles.
    #
    # Example:
    #   config.isolated_app_dirs = ["rvb"]
    attr_accessor :isolated_app_dirs

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

    # Also print ReactManifest status lines directly to stdout, in addition
    # to Rails.logger (which always receives them regardless of this flag).
    # Off by default: many development setups already have Rails.logger
    # broadcast to the terminal (RAILS_LOG_TO_STDOUT, Docker/Foreman, etc.),
    # and enabling this on top of that prints every line twice. Turn it on
    # only if your Rails.logger does NOT already surface output in your
    # terminal and you want a guaranteed visible line per event.
    attr_accessor :stdout_logging

    # Explicit symbol-to-require-path mapping for external globals.
    # Use for third-party libraries that export a PascalCase or camelCase symbol
    # not located inside ux_root (e.g. MiniSearch, Chart.js wrappers).
    #
    # Keys are exact symbol names (case-sensitive); values are the Sprockets
    # require path that should be emitted into the controller manifest.
    #
    # Example:
    #   config.external_providers = { "MiniSearch" => "mini-search", "axios" => "vendor/axios" }
    attr_accessor :external_providers

    # Extra root directories (absolute or relative to Rails.root) to scan for
    # symbol definitions outside of ux_root.  Symbols found here are added to
    # the shared symbol index and will trigger an include when used by a
    # controller.  Empty by default; files in these dirs are subject to the
    # same +exclude_paths+ and +extensions+ filters.
    #
    # Example:
    #   config.external_roots = ["app/assets/javascripts/vendor_components"]
    attr_accessor :external_roots

    def initialize
      @ux_root           = "app/assets/javascripts/ux"
      @app_dir           = "app"
      @output_dir        = "app/assets/javascripts"
      @manifest_subdir   = "ux_manifests"
      @manage_gitignore  = true
      @shared_bundle     = "ux_shared"
      @auto_shared       = true
      @always_include    = []
      @ignore            = []
      @isolated_app_dirs = []
      @exclude_paths     = %w[react react_dev vendor]
      @size_threshold_kb = 500
      @extensions        = %w[js jsx]
      @dry_run           = false
      @verbose           = false
      @stdout_logging    = false
      @external_providers = {}
      @external_roots     = []
    end

    def dry_run?
      !!@dry_run
    end

    def auto_shared?
      !!@auto_shared
    end

    def verbose?
      !!@verbose
    end

    def stdout_logging?
      !!@stdout_logging
    end

    def manage_gitignore?
      !!@manage_gitignore
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

    def excluded_path?(abs_path)
      parts = abs_path.split(File::SEPARATOR)
      exclude_paths.any? { |ep| parts.include?(ep) }
    end

    def normalized_manifest_subdir
      manifest_subdir.to_s.gsub(%r{\A/+|/+\z}, "")
    end

    def cache_key
      [ux_root, app_dir, extensions, always_include, exclude_paths, external_providers, isolated_app_dirs].hash
    end
  end
end
