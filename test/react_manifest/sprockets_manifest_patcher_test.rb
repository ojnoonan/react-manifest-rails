require "test_helper"

class SprocketsManifestPatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @patcher = ReactManifest::SprocketsManifestPatcher.new(@config)
  end

  def manifest_path
    Rails.root.join("app", "assets", "config", "manifest.js").to_s
  end

  def write_manifest(content)
    FileUtils.mkdir_p(File.dirname(manifest_path))
    File.write(manifest_path, content)
  end

  def read_manifest
    File.read(manifest_path, encoding: "utf-8")
  end

  def test_patch_returns_status_patched_for_fresh_manifest
    write_manifest(<<~JS)
      //= link_tree ../images
      //= link_directory ../javascripts .js
      //= link_directory ../stylesheets .css
    JS
    assert_equal :patched, @patcher.patch!.status
  end

  def test_patch_adds_link_tree_directive_after_last_directive_line
    write_manifest(<<~JS)
      //= link_tree ../images
      //= link_directory ../javascripts .js
      //= link_directory ../stylesheets .css
    JS
    @patcher.patch!
    content = read_manifest
    lines = content.lines
    last_directive_idx = lines.rindex { |l| l.include?("//=") }
    link_tree_idx = lines.index { |l| l.include?("link_tree") && l.include?("ux_manifests") }
    refute_nil link_tree_idx
    assert link_tree_idx <= last_directive_idx + 1
  end

  def test_patch_does_not_duplicate_directive_on_second_call
    write_manifest(<<~JS)
      //= link_directory ../javascripts .js
    JS
    @patcher.patch!
    @patcher.patch!
    assert_equal 1, read_manifest.scan("ux_manifests").size
  end

  def test_patch_reflects_configured_manifest_subdir
    write_manifest(<<~JS)
      //= link_directory ../javascripts .js
    JS
    ReactManifest.configure { |c| c.manifest_subdir = "my_bundles" }
    ReactManifest::SprocketsManifestPatcher.new(@config).patch!
    assert_includes read_manifest, "my_bundles"
  end

  def test_patch_returns_already_patched_when_directive_already_present
    write_manifest("//= link_tree ../javascripts/ux_manifests .js\n")
    assert_equal :already_patched, @patcher.patch!.status
  end

  def test_patch_does_not_modify_already_patched_manifest
    content = "//= link_tree ../javascripts/ux_manifests .js\n"
    write_manifest(content)
    @patcher.patch!
    assert_equal content, read_manifest
  end

  def test_patch_returns_not_found_when_manifest_does_not_exist
    FileUtils.rm_f(manifest_path)
    assert_equal :not_found, @patcher.patch!.status
  end

  def test_patch_returns_dry_run_status_in_dry_run_mode
    write_manifest("//= link_directory ../javascripts .js\n")
    ReactManifest.configure { |c| c.dry_run = true }
    assert_equal :dry_run, ReactManifest::SprocketsManifestPatcher.new(@config).patch!.status
  end

  def test_patch_does_not_modify_manifest_in_dry_run_mode
    original = "//= link_directory ../javascripts .js\n"
    write_manifest(original)
    ReactManifest.configure { |c| c.dry_run = true }
    ReactManifest::SprocketsManifestPatcher.new(@config).patch!
    assert_equal original, read_manifest
  end

  def test_already_patched_returns_false_when_directive_absent
    write_manifest("//= link_directory ../javascripts .js\n")
    refute @patcher.already_patched?
  end

  def test_already_patched_returns_true_when_directive_present
    write_manifest("//= link_tree ../javascripts/ux_manifests .js\n")
    assert @patcher.already_patched?
  end

  def test_already_patched_returns_false_when_manifest_does_not_exist
    FileUtils.rm_f(manifest_path)
    refute @patcher.already_patched?
  end
end
