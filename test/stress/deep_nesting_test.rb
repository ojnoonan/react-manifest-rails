require "test_helper"
require_relative "../support/stress_fixture_builder"

class DeepNestingTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("react_manifest_stress")
    Rails.root = @tmpdir
    ReactManifest.reset!
    StressFixtureBuilder.build_deep_nesting(@tmpdir)
    StressFixtureBuilder.configure_for(@tmpdir)
    @config    = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ReactManifest.reset!
  end

  def test_generates_a_top_level_manifest_for_the_admin_controller
    @generator.run!
    assert File.exist?(File.join(@config.abs_manifest_dir, "ux_admin.js"))
  end

  def test_admin_manifest_recursively_includes_files_from_all_sub_levels
    @generator.run!
    content = File.read(File.join(@config.abs_manifest_dir, "ux_admin.js"))
    assert_includes content, "//= require ux/app/admin/reports/summary/summary_index"
    assert_includes content, "//= require ux/app/admin/reports/summary/summary_show"
  end

  def test_admin_manifest_carries_the_auto_generated_header
    @generator.run!
    content = File.read(File.join(@config.abs_manifest_dir, "ux_admin.js"))
    assert_includes content, "AUTO-GENERATED"
  end

  def test_no_spurious_manifests_are_created_for_intermediate_namespace_dirs
    @generator.run!
    refute File.exist?(File.join(@config.abs_manifest_dir, "ux_admin_reports.js"))
    refute File.exist?(File.join(@config.abs_manifest_dir, "ux_admin_reports_summary.js"))
  end
end
