require "test_helper"

class ReconcileGitignoreTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def gitignore_path
    Rails.root.join(".gitignore").to_s
  end

  def test_reconcile_adds_entry_when_managed
    ReactManifest.reconcile_gitignore!(@config)
    assert_includes File.read(gitignore_path), "app/assets/javascripts/ux_manifests/*.js"
  end

  def test_reconcile_is_noop_when_management_disabled
    @config.manage_gitignore = false
    ReactManifest.reconcile_gitignore!(@config)
    refute File.exist?(gitignore_path)
  end

  def test_reconcile_returns_whether_it_appended
    assert_equal true, ReactManifest.reconcile_gitignore!(@config)
    assert_equal false, ReactManifest.reconcile_gitignore!(@config)
  end
end
