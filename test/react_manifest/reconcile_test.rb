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

  def test_old_format_manifests_are_regenerated_on_run
    # Seed a stale, hand-written manifest that references a file that no longer exists.
    dir = @config.abs_manifest_dir
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "ux_shared.js"),
               "// AUTO-GENERATED — DO NOT EDIT\n//= require ux/lib/gone_file\n")

    ReactManifest::Generator.new(@config).run!

    refute_includes File.read(File.join(dir, "ux_shared.js")), "gone_file"
  end

  def test_reconcile_idempotent_second_boot_appends_nothing
    ReactManifest.reconcile_gitignore!(@config)
    before = File.read(gitignore_path)
    ReactManifest.reconcile_gitignore!(@config)
    assert_equal before, File.read(gitignore_path)
  end

  def test_reconcile_survives_unwritable_gitignore
    FileUtils.mkdir_p(File.dirname(gitignore_path))
    # Make .gitignore a directory so a write fails; reconcile must swallow it.
    FileUtils.mkdir_p(gitignore_path)
    begin
      result = ReactManifest.reconcile_gitignore!(@config)
      assert_equal false, result, "reconcile should return false (swallowed error), not raise"
    rescue StandardError => e
      flunk "reconcile_gitignore! raised instead of swallowing: #{e.class}: #{e.message}"
    ensure
      FileUtils.rm_rf(gitignore_path)
    end
  end
end
