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

  class FakeApp
    def config
      OpenStruct.new(react_manifest: nil)
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
unless defined?(Rails)
  Rails = FakeRails
end

# Load the gem's lib files individually, skipping the Railtie
# (Railtie requires real Rails; unit tests use FakeRails)
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
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
      config  = configuration
      output  = config.abs_output_dir
      bundles = []

      if bundle_exists?(output, config.shared_bundle)
        bundles << config.shared_bundle
      end

      config.always_include.each do |b|
        bundles << b if bundle_exists?(output, b) && !bundles.include?(b)
      end

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

  def with_temp_rails_root(&block)
    Dir.mktmpdir("react_manifest_test") do |tmpdir|
      Rails.root = tmpdir
      ReactManifest.reset!
      yield tmpdir
    end
  end

  def fixture_config(root)
    ReactManifest.configure do |c|
      c.ux_root    = "app/assets/javascripts/ux"
      c.app_dir    = "app"
      c.output_dir = "app/assets/javascripts"
      c.dry_run    = false
      c.verbose    = false
    end
    ReactManifest.configuration
  end

  def copy_fixtures_to(tmpdir)
    src = File.expand_path("fixtures/dummy/app/assets/javascripts", __dir__)
    dst = File.join(tmpdir, "app/assets/javascripts")
    FileUtils.mkdir_p(dst)
    FileUtils.cp_r(Dir.glob("#{src}/*"), dst)
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
