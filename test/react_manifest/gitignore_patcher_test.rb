require "test_helper"

class GitignorePatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @patcher = ReactManifest::GitignorePatcher.new(@config)
  end

  def gitignore_path
    Rails.root.join(".gitignore").to_s
  end

  def test_pattern_is_derived_from_config
    assert_equal "app/assets/javascripts/ux_manifests/*.js", @patcher.pattern
  end

  def test_appends_entry_when_missing
    result = @patcher.patch!
    assert result.appended
    assert_includes File.read(gitignore_path), "app/assets/javascripts/ux_manifests/*.js"
  end

  def test_is_idempotent_and_does_not_double_append
    @patcher.patch!
    result = ReactManifest::GitignorePatcher.new(@config).patch!
    refute result.appended
    occurrences = File.read(gitignore_path).scan("app/assets/javascripts/ux_manifests/*.js\n").size
    assert_equal 1, occurrences
  end

  def test_respects_existing_entry_in_a_populated_gitignore
    File.write(gitignore_path,
               "/log\napp/assets/javascripts/ux_manifests/*.js\napp/assets/javascripts/ux_manifests/*.json\n/tmp\n")
    result = @patcher.patch!
    refute result.appended
  end

  def test_creates_keep_in_manifest_dir
    @patcher.patch!
    assert File.exist?(File.join(@config.abs_manifest_dir, ".keep"))
  end

  def test_appends_with_leading_newline_when_file_lacks_trailing_newline
    File.write(gitignore_path, "/log")
    @patcher.patch!
    content = File.read(gitignore_path)
    assert_includes content, "/log\napp/assets/javascripts/ux_manifests/*.js"
  end

  def test_keep_is_not_recreated_when_present
    @patcher.patch!
    result = ReactManifest::GitignorePatcher.new(@config).patch!
    refute result.keep_created
  end

  def test_also_ignores_the_component_index_sidecar
    @patcher.patch!
    assert_equal "app/assets/javascripts/ux_manifests/*.json", @patcher.json_pattern
    assert_includes File.read(gitignore_path), "app/assets/javascripts/ux_manifests/*.json"
  end

  def test_adds_only_the_missing_json_line_to_an_existing_gitignore
    File.write(gitignore_path, "app/assets/javascripts/ux_manifests/*.js\n")
    result = @patcher.patch!
    assert result.appended
    assert_equal 1, File.read(gitignore_path).scan("ux_manifests/*.js\n").size
  end
end
