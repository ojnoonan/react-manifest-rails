require "set"
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
require "react_manifest/railtie" if defined?(Rails)

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
      output  = config.abs_output_dir
      bundles = []

      # 1. Shared bundle always first
      if bundle_exists?(output, config.shared_bundle)
        bundles << config.shared_bundle
      end

      # 2. always_include bundles (e.g. ux_main)
      config.always_include.each do |b|
        bundles << b if bundle_exists?(output, b) && !bundles.include?(b)
      end

      # 3. Controller-specific bundle
      # Try fully-namespaced first: admin/users → ux_admin_users
      # Then drop segments: ux_admin
      controller_candidates(ctrl_name).each do |candidate|
        if bundle_exists?(output, candidate) && !bundles.include?(candidate)
          bundles << candidate
          break
        end
      end

      bundles
    end

    private

    def bundle_exists?(output_dir, bundle_name)
      File.exist?(File.join(output_dir, "#{bundle_name}.js"))
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
