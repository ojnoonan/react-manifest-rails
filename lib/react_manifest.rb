require "fileutils"

require "react_manifest/version"
require "react_manifest/configuration"
require "react_manifest/tree_classifier"
require "react_manifest/scanner"
require "react_manifest/dependency_map"
require "react_manifest/generator"
require "react_manifest/application_analyzer"
require "react_manifest/application_migrator"
require "react_manifest/watcher"
require "react_manifest/reporter"
require "react_manifest/view_helpers"

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

    private

    def resolve_bundle_reference(config, bundle_name)
      manifest_path = File.join(config.abs_manifest_dir, "#{bundle_name}.js")
      return bundle_name if File.exist?(manifest_path)

      # Backward compatibility for apps still holding legacy manifests in output_dir root.
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
