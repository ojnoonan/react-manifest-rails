require "test_helper"

class ConfigurationTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest::Configuration.new
  end

  def test_default_ux_root
    assert_equal "app/assets/javascripts/ux", @config.ux_root
  end

  def test_default_app_dir
    assert_equal "app", @config.app_dir
  end

  def test_default_output_dir
    assert_equal "app/assets/javascripts", @config.output_dir
  end

  def test_default_manifest_subdir
    assert_equal "ux_manifests", @config.manifest_subdir
  end

  def test_default_shared_bundle
    assert_equal "ux_shared", @config.shared_bundle
  end

  def test_default_always_include_is_empty_array
    assert_equal [], @config.always_include
  end

  def test_default_ignore_is_empty_array
    assert_equal [], @config.ignore
  end

  def test_default_isolated_app_dirs_is_empty_array
    assert_equal [], @config.isolated_app_dirs
  end

  def test_default_exclude_paths_includes_vendor_and_react
    assert_includes @config.exclude_paths, "vendor"
    assert_includes @config.exclude_paths, "react"
  end

  def test_default_size_threshold_kb_is_five_hundred
    assert_equal 500, @config.size_threshold_kb
  end

  def test_default_extensions_are_js_and_jsx
    assert_equal %w[js jsx], @config.extensions
  end

  def test_dry_run_disabled_by_default
    assert_equal false, @config.dry_run?
  end

  def test_verbose_disabled_by_default
    assert_equal false, @config.verbose?
  end

  def test_stdout_logging_disabled_by_default
    assert_equal false, @config.stdout_logging?
  end

  def test_abs_ux_root_starts_with_rails_root
    assert @config.abs_ux_root.start_with?(Rails.root.to_s)
  end

  def test_abs_ux_root_ends_with_ux_path
    assert @config.abs_ux_root.end_with?("app/assets/javascripts/ux")
  end

  def test_abs_output_dir_starts_with_rails_root
    assert @config.abs_output_dir.start_with?(Rails.root.to_s)
  end

  def test_abs_output_dir_ends_with_output_path
    assert @config.abs_output_dir.end_with?("app/assets/javascripts")
  end

  def test_abs_manifest_dir_starts_with_rails_root
    assert @config.abs_manifest_dir.start_with?(Rails.root.to_s)
  end

  def test_abs_manifest_dir_ends_with_manifest_subdir_path
    assert @config.abs_manifest_dir.end_with?("app/assets/javascripts/ux_manifests")
  end

  def test_abs_app_dir_equals_ux_root_joined_with_app_dir
    assert_equal File.join(@config.abs_ux_root, @config.app_dir), @config.abs_app_dir
  end

  def test_extensions_glob_for_default_extensions
    assert_equal "*.{js,jsx}", @config.extensions_glob
  end

  def test_extensions_glob_reflects_custom_extensions
    @config.extensions = %w[js jsx ts tsx]
    assert_equal "*.{js,jsx,ts,tsx}", @config.extensions_glob
  end

  def test_extensions_pattern_matches_js_files
    assert_match @config.extensions_pattern, "foo.js"
  end

  def test_extensions_pattern_matches_jsx_files
    assert_match @config.extensions_pattern, "foo.jsx"
  end

  def test_extensions_pattern_does_not_match_ts_files_by_default
    refute_match @config.extensions_pattern, "foo.ts"
  end

  def test_extensions_pattern_reflects_custom_ts_tsx_extensions
    @config.extensions = %w[js jsx ts tsx]
    assert_match @config.extensions_pattern, "foo.ts"
    assert_match @config.extensions_pattern, "foo.tsx"
  end

  def test_dry_run_true_when_set
    @config.dry_run = true
    assert @config.dry_run?
  end

  def test_verbose_true_when_set
    @config.verbose = true
    assert @config.verbose?
  end

  def test_stdout_logging_true_when_set
    @config.stdout_logging = true
    assert @config.stdout_logging?
  end

  def test_stdout_logging_false_when_disabled
    @config.stdout_logging = false
    refute @config.stdout_logging?
  end

  def test_external_providers_defaults_to_empty_hash
    assert_equal({}, @config.external_providers)
  end

  def test_external_providers_accepts_symbol_to_require_path_mapping
    @config.external_providers = { "MiniSearch" => "mini-search", "axios" => "axios" }
    assert_equal "mini-search", @config.external_providers["MiniSearch"]
    assert_equal "axios", @config.external_providers["axios"]
  end

  def test_external_roots_defaults_to_empty_array
    assert_equal [], @config.external_roots
  end

  def test_external_roots_accepts_array_of_directory_paths
    @config.external_roots = ["app/assets/javascripts/vendor_components"]
    assert_equal ["app/assets/javascripts/vendor_components"], @config.external_roots
  end

  def test_excluded_path_true_when_segment_matches
    @config.exclude_paths = ["vendor"]
    assert @config.excluded_path?("/app/assets/ux/vendor/foo.js")
  end

  def test_excluded_path_false_when_only_prefix_matches
    @config.exclude_paths = ["vendor"]
    refute @config.excluded_path?("/app/assets/ux/vendor_custom/foo.js")
  end

  def test_excluded_path_false_when_no_segment_matches
    @config.exclude_paths = ["vendor"]
    refute @config.excluded_path?("/app/assets/ux/components/foo.js")
  end

  def test_excluded_path_false_when_exclude_paths_empty
    @config.exclude_paths = []
    refute @config.excluded_path?("/app/assets/ux/vendor/foo.js")
  end

  def test_cache_key_is_stable_on_unchanged_config
    assert_equal @config.cache_key, @config.cache_key
  end

  def test_cache_key_changes_after_always_include_mutation
    before = @config.cache_key
    @config.always_include = ["ux_main"]
    refute_equal before, @config.cache_key
  end

  def test_cache_key_changes_after_isolated_app_dirs_mutation
    before = @config.cache_key
    @config.isolated_app_dirs = ["rvb"]
    refute_equal before, @config.cache_key
  end

  def test_cache_key_changes_after_exclude_paths_mutation
    before = @config.cache_key
    @config.exclude_paths = []
    refute_equal before, @config.cache_key
  end

  def test_auto_shared_defaults_to_true
    assert_equal true, ReactManifest::Configuration.new.auto_shared?
  end

  def test_auto_shared_can_be_disabled
    config = ReactManifest::Configuration.new
    config.auto_shared = false
    assert_equal false, config.auto_shared?
  end

  def test_manage_gitignore_defaults_to_true
    assert_equal true, ReactManifest::Configuration.new.manage_gitignore?
  end

  def test_manage_gitignore_can_be_disabled
    config = ReactManifest::Configuration.new
    config.manage_gitignore = false
    assert_equal false, config.manage_gitignore?
  end
end
