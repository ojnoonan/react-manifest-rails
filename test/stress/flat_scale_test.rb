require "benchmark"
require "test_helper"
require_relative "../support/stress_fixture_builder"

class FlatScaleTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("react_manifest_stress")
    Rails.root = @tmpdir
    ReactManifest.reset!
    StressFixtureBuilder.build_flat(@tmpdir, controller_count: 100, files_per_controller: 3)
    StressFixtureBuilder.configure_for(@tmpdir)
    @config    = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ReactManifest.reset!
  end

  def test_generates_one_manifest_per_controller
    @generator.run!
    manifests = Dir.glob(File.join(@config.abs_manifest_dir, "ux_ctrl_*.js"))
    assert_equal 100, manifests.length
  end

  def test_ux_shared_js_is_generated
    @generator.run!
    assert File.exist?(File.join(@config.abs_manifest_dir, "ux_shared.js"))
  end

  def test_each_controller_manifest_requires_only_its_own_source_files
    @generator.run!
    (1..5).each do |i|
      path    = File.join(@config.abs_manifest_dir, "ux_ctrl_#{i}.js")
      content = File.read(path)
      assert_includes content, "//= require ux/app/ctrl_#{i}/ctrl_#{i}_0",
                      "ux_ctrl_#{i}.js is missing its own source requires"
    end
  end

  def test_all_generated_manifests_carry_the_auto_generated_header
    @generator.run!
    Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js")).each do |path|
      assert_includes File.read(path), "AUTO-GENERATED",
                      "#{File.basename(path)} is missing AUTO-GENERATED header"
    end
  end

  def test_completes_within_10_seconds
    elapsed = Benchmark.realtime { @generator.run! }
    assert_operator elapsed, :<, 10
  end
end
