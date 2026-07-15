require "fileutils"
require "set"

require "react_manifest/version"
require "react_manifest/logging"
require "react_manifest/configuration"
require "react_manifest/path_utils"
require "react_manifest/tree_classifier"
require "react_manifest/symbol_extractor"
require "react_manifest/scanner"
require "react_manifest/dependency_map"
require "react_manifest/generator"
require "react_manifest/application_analyzer"
require "react_manifest/application_migrator"
require "react_manifest/layout_patcher"
require "react_manifest/sprockets_manifest_patcher"
require "react_manifest/gitignore_patcher"
require "react_manifest/watcher"
require "react_manifest/reporter"
require "react_manifest/view_helpers"

# rubocop:disable Metrics/ModuleLength
module ReactManifest
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset!
      @configuration = nil
      @component_maps_cache = nil
      Scanner.clear_cache!
    end

    # Drop the cached component-symbol -> bundle map used by
    # resolve_bundle_for_component / resolve_bundles_for_component(_direct).
    # Unlike reset!, this does NOT touch the current Configuration — safe to
    # call whenever ux/ files change (e.g. from the file watcher) so newly
    # added controllers/components are picked up without losing app config.
    def invalidate_component_maps!
      @component_maps_cache = nil
    end

    # Returns the ordered list of bundle logical names for a given controller.
    # Used by the react_bundle_tag view helper.
    def resolve_bundles(ctrl_name)
      config  = configuration
      bundles = []

      # 1. Shared bundle always first
      shared = resolve_bundle_reference(config, config.shared_bundle)
      bundles << shared if shared

      # 2. always_include bundles (e.g. ux_main)
      config.always_include.each do |b|
        resolved = resolve_bundle_reference(config, b)
        bundles << resolved if resolved && !bundles.include?(resolved)
      end

      # 3. Controller-specific bundle
      # Try fully-namespaced first: admin/users → ux_admin_users
      # Then drop segments: ux_admin
      controller_candidates(ctrl_name).each do |candidate|
        resolved = resolve_bundle_reference(config, candidate)
        if resolved && !bundles.include?(resolved)
          bundles << resolved
          break
        end
      end

      bundles
    end

    # Ensure the manifest dir is gitignored (and .keep present). Honors
    # config.manage_gitignore. Returns true if it appended the .gitignore entry.
    # Best-effort: a filesystem error is logged and swallowed (never breaks boot).
    def reconcile_gitignore!(config = configuration)
      return false unless config.manage_gitignore?

      GitignorePatcher.new(config).reconcile!
    rescue StandardError => e
      Rails.logger&.warn("[ReactManifest] gitignore reconcile skipped: #{e.message}")
      false
    end

    # Resolve a controller bundle from a React component symbol.
    #
    # This is primarily used to support react-rails `react_component` calls,
    # where the requested component name is known and may not align 1:1 with
    # controller_path-derived bundle names.
    def resolve_bundle_for_component(component_name)
      resolve_bundles_for_component_direct(component_name).last
    end

    # Resolve the direct bundle list needed for a React component symbol.
    # Returns shared first (if present), then the component's owning bundle.
    #
    # Unlike resolve_bundles_for_component, this does not include transitive
    # controller dependencies because generated controller manifests already
    # inline those files via Sprockets require directives.
    def resolve_bundles_for_component_direct(component_name)
      name = component_name.to_s
      return [] if name.empty?

      config = configuration
      maps = component_maps(config)
      root_bundle = maps[:symbol_to_bundle][name]
      return [] unless root_bundle

      bundles = []
      shared = resolve_bundle_reference(config, config.shared_bundle)
      bundles << shared if shared

      root = resolve_bundle_reference(config, root_bundle)
      bundles << root if root && !bundles.include?(root)

      bundles
    end

    # Resolve all controller bundles needed for a React component symbol.
    # Includes transitive controller-bundle dependencies inferred from
    # component symbol usage across ux/app/* directories.
    def resolve_bundles_for_component(component_name)
      name = component_name.to_s
      return [] if name.empty?

      config = configuration
      maps = component_maps(config)
      root_bundle = maps[:symbol_to_bundle][name]
      return [] unless root_bundle

      ordered = []
      visiting = Set.new
      visited = Set.new

      walk = lambda do |bundle_name|
        return if visited.include?(bundle_name) || visiting.include?(bundle_name)

        visiting << bundle_name
        maps[:bundle_dependencies].fetch(bundle_name, Set.new).each { |dep| walk.call(dep) }
        visiting.delete(bundle_name)

        visited << bundle_name
        ordered << bundle_name
      end

      walk.call(root_bundle)

      ordered.filter_map { |bundle_name| resolve_bundle_reference(config, bundle_name) }
    end

    private

    def component_bundle_map(config)
      component_maps(config)[:symbol_to_bundle]
    end

    def component_maps(config)
      key = config.cache_key
      if @component_maps_cache
        cached_key, cached_maps = @component_maps_cache
        return cached_maps if cached_key == key
      end

      controller_dirs = TreeClassifier.new(config).classify.controller_dirs
      symbol_to_bundle = {}
      bundle_own_symbols = Hash.new { |h, k| h[k] = Set.new }
      bundle_files = Hash.new { |h, k| h[k] = [] }
      bundle_dependencies = Hash.new { |h, k| h[k] = Set.new }

      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in_controller(ctrl[:path], config)
        bundle_files[bundle_name].concat(files)
        isolated = config.isolated_app_dirs.include?(ctrl[:name])

        files.each do |file_path|
          extract_defined_symbols(file_path).each do |symbol|
            next unless symbol.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            # Keep first writer to ensure deterministic behavior if a symbol is duplicated.
            # Isolated dirs never register into the shared symbol index (see
            # Generator#build_controller_context for the full rationale).
            symbol_to_bundle[symbol] ||= bundle_name unless isolated
            bundle_own_symbols[bundle_name] << symbol
          end
        end
      end

      bundle_files.each do |bundle_name, files|
        own_symbols = bundle_own_symbols[bundle_name]

        files.each do |file_path|
          extract_used_component_symbols(file_path).each do |symbol|
            # A symbol the bundle defines itself is always satisfied locally —
            # never attribute it to another bundle just because that symbol
            # name happens to collide with something defined elsewhere.
            next if own_symbols.include?(symbol)

            dep_bundle = symbol_to_bundle[symbol]
            next unless dep_bundle && dep_bundle != bundle_name

            bundle_dependencies[bundle_name] << dep_bundle
          end
        end
      end

      maps = {
        symbol_to_bundle: symbol_to_bundle,
        bundle_dependencies: bundle_dependencies
      }
      @component_maps_cache = [key, maps]
      maps
    end

    def js_files_in_controller(dir, config)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .sort
    end

    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_definitions(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def resolve_bundle_reference(config, bundle_name)
      subdir = config.normalized_manifest_subdir
      manifest_path = File.join(config.abs_manifest_dir, "#{bundle_name}.js")
      if File.exist?(manifest_path)
        # Return the full Sprockets logical path so javascript_include_tag resolves
        # correctly: files in ux_manifests/ have logical path ux_manifests/<name>.
        return subdir.empty? ? bundle_name : "#{subdir}/#{bundle_name}"
      end

      # Backward compatibility: apps that wrote manifests directly to output_dir root
      # before manifest_subdir was introduced keep working with bare bundle names.
      legacy_path = File.join(config.abs_output_dir, "#{bundle_name}.js")
      return bundle_name if File.exist?(legacy_path)

      nil
    end

    def controller_candidates(ctrl_name)
      # "admin/reports/summary" → ["ux_admin_reports_summary", "ux_admin_reports", "ux_admin", "ux_summary"]
      parts = ctrl_name.to_s.split("/")
      candidates = []

      # Longest match first (most specific)
      parts.length.downto(1) do |len|
        candidates << "ux_#{parts.first(len).join('_')}"
      end

      # Also try just the last segment (common Rails pattern)
      last = parts.last
      candidates << "ux_#{last}" unless candidates.include?("ux_#{last}")

      candidates.uniq
    end
  end
end
# rubocop:enable Metrics/ModuleLength
