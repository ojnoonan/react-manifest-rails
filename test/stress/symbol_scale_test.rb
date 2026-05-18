require "benchmark"
require "test_helper"
require_relative "../support/stress_fixture_builder"

class SymbolScaleTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("react_manifest_stress")
    Rails.root = @tmpdir
    ReactManifest.reset!
    StressFixtureBuilder.build_symbol_scale(@tmpdir, shared_files: 50, symbols_per_file: 10)
    StressFixtureBuilder.configure_for(@tmpdir)
    @config    = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ReactManifest.reset!
  end

  def test_ux_shared_js_requires_all_50_shared_component_files
    @generator.run!
    content = File.read(File.join(@config.abs_manifest_dir, "ux_shared.js"))
    50.times do |fi|
      assert_includes content, "//= require ux/components/group_#{fi}",
                      "ux_shared.js is missing group_#{fi}"
    end
  end

  def test_ux_shared_js_carries_the_auto_generated_header
    @generator.run!
    content = File.read(File.join(@config.abs_manifest_dir, "ux_shared.js"))
    assert_includes content, "AUTO-GENERATED"
  end

  def test_completes_within_10_seconds
    elapsed = Benchmark.realtime { @generator.run! }
    assert_operator elapsed, :<, 10
  end
end
