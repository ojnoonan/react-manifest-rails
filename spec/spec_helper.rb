require "simplecov"
require "set"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/test/"
end

require "fileutils"
require "tmpdir"
require "pathname"

# Stand up a minimal Rails-like environment for unit tests
# (without loading the full Rails stack)
module FakeRails
  class FakeRoot
    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path)
    end

    def join(*args)
      @path.join(*args)
    end

    def to_s
      @path.to_s
    end
  end

  class FakeLogger
    def info(msg);  end
    def warn(msg);  end
    def error(msg); end
  end

  FakeConfig = Struct.new(:react_manifest)

  class FakeApp
    def config
      FakeConfig.new(nil)
    end
  end

  def self.root=(path)
    @root = FakeRoot.new(path)
  end

  def self.root
    @root
  end

  def self.logger
    @logger ||= FakeLogger.new
  end

  def self.env
    "test"
  end

  def self.application
    FakeApp.new
  end
end

# Stub Rails constant for unit tests
Rails = FakeRails unless defined?(Rails)

# Load the gem's lib files individually, skipping the Railtie
# (Railtie requires real Rails; unit tests use FakeRails)
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "react_manifest/version"
require "react_manifest/configuration"
require "react_manifest/tree_classifier"
require "react_manifest/scanner"
require "react_manifest/dependency_map"
require "react_manifest/generator"
require "react_manifest/application_analyzer"
require "react_manifest/application_migrator"
require "react_manifest/layout_patcher"
require "react_manifest/sprockets_manifest_patcher"
require "react_manifest/watcher"
require "react_manifest/reporter"
require "react_manifest/view_helpers"

# Load the top-level module (without auto-requiring railtie)
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

    def resolve_bundles(ctrl_name)
      config = configuration
      bundles = []

      shared = resolve_bundle_reference(config, config.shared_bundle)
      bundles << shared if shared

      config.always_include.each do |b|
        resolved = resolve_bundle_reference(config, b)
        bundles << resolved if resolved && !bundles.include?(resolved)
      end

      controller_candidates(ctrl_name).each do |candidate|
        resolved = resolve_bundle_reference(config, candidate)
        if resolved && !bundles.include?(resolved)
          bundles << resolved
          break
        end
      end

      bundles
    end

    def resolve_bundle_for_component(component_name)
      resolve_bundles_for_component(component_name).last
    end

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
      controller_dirs = TreeClassifier.new(config).classify.controller_dirs
      symbol_to_bundle = {}
      bundle_files = Hash.new { |h, k| h[k] = [] }
      bundle_dependencies = Hash.new { |h, k| h[k] = Set.new }

      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in_controller(ctrl[:path], config)
        bundle_files[bundle_name].concat(files)

        files.each do |file_path|
          extract_defined_symbols(file_path).each do |symbol|
            next unless symbol.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            symbol_to_bundle[symbol] ||= bundle_name
          end
        end
      end

      bundle_files.each do |bundle_name, files|
        files.each do |file_path|
          extract_used_component_symbols(file_path).each do |symbol|
            dep_bundle = symbol_to_bundle[symbol]
            next unless dep_bundle && dep_bundle != bundle_name

            bundle_dependencies[bundle_name] << dep_bundle
          end
        end
      end

      {
        symbol_to_bundle: symbol_to_bundle,
        bundle_dependencies: bundle_dependencies
      }
    end

    def js_files_in_controller(dir, config)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .sort
    end

    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      symbols = []
      Scanner::DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")

      local_syms = Set.new
      Scanner::DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| local_syms << m[0] }
      end

      symbols = []
      content.scan(Scanner::PASCAL_TOKEN_PATTERN) { |m| symbols << m[0] unless local_syms.include?(m[0]) }
      content.scan(Scanner::HOOK_TOKEN_PATTERN)   { |m| symbols << m[0] unless local_syms.include?(m[0]) }

      symbols.uniq
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def resolve_bundle_reference(config, bundle_name)
      manifest_path = File.join(config.abs_manifest_dir, "#{bundle_name}.js")
      return bundle_name if File.exist?(manifest_path)

      legacy_path = File.join(config.abs_output_dir, "#{bundle_name}.js")
      return bundle_name if File.exist?(legacy_path)

      nil
    end

    def controller_candidates(ctrl_name)
      parts = ctrl_name.to_s.split("/")
      candidates = []
      parts.length.downto(1) do |len|
        candidates << "ux_#{parts.first(len).join('_')}"
      end
      last = parts.last
      candidates << "ux_#{last}" unless candidates.include?("ux_#{last}")
      candidates.uniq
    end
  end
end

# Shared fixture helpers
module FixtureHelpers
  FIXTURE_UX_ROOT = File.expand_path("fixtures/dummy/app/assets/javascripts/ux", __dir__)
  FIXTURE_JS_ROOT = File.expand_path("fixtures/dummy/app/assets/javascripts", __dir__)

  def with_temp_rails_root
    Dir.mktmpdir("react_manifest_test") do |tmpdir|
      Rails.root = tmpdir
      ReactManifest.reset!
      yield tmpdir
    end
  end

  def fixture_config(_root)
    ReactManifest.configure do |c|
      c.ux_root    = "app/assets/javascripts/ux"
      c.app_dir    = "app"
      c.output_dir = "app/assets/javascripts"
      c.manifest_subdir = "ux_manifests"
      c.dry_run    = false
      c.verbose    = false
    end
    ReactManifest.configuration
  end

  def copy_fixtures_to(tmpdir)
    # Copy all fixture app/ subdirs (assets/javascripts, views, etc.) into tmpdir
    src_app = File.expand_path("fixtures/dummy/app", __dir__)
    dst_app = File.join(tmpdir, "app")
    FileUtils.mkdir_p(dst_app)
    Dir.glob("#{src_app}/*/").each do |subdir|
      FileUtils.cp_r(subdir, dst_app)
    end
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers

  config.before(:each) do
    ReactManifest.reset!
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
