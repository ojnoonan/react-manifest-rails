require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/test/"
end

require "minitest/autorun"
require "mocha/minitest"
require "fileutils"
require "tmpdir"
require "pathname"
require "set"

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
    def debug(msg); end
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

  class FakeEnv < String
    def development?
      self == "development"
    end

    def test?
      self == "test"
    end

    def production?
      self == "production"
    end
  end

  def self.env
    @env ||= FakeEnv.new("test")
  end

  def self.application
    FakeApp.new
  end
end

Rails = FakeRails unless defined?(Rails)

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "react_manifest"

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
    src_app = File.expand_path("fixtures/dummy/app", __dir__)
    dst_app = File.join(tmpdir, "app")
    FileUtils.mkdir_p(dst_app)
    Dir.glob("#{src_app}/*/").each do |subdir|
      FileUtils.cp_r(subdir, dst_app)
    end
  end
end

class ReactManifestTest < Minitest::Test
  include FixtureHelpers

  def setup
    @tmpdir = Dir.mktmpdir("react_manifest_test")
    Rails.root = @tmpdir
    copy_fixtures_to(@tmpdir)
    fixture_config(@tmpdir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ReactManifest.reset!
  end
end
