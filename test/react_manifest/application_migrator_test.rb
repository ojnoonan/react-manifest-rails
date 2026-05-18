require "test_helper"

class ApplicationMigratorTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @migrator = ReactManifest::ApplicationMigrator.new(@config)
    @app_js_path = File.join(@config.abs_output_dir, "application.js")
  end

  def test_keeps_unknown_non_ux_requires_in_migrated_file
    File.write(@app_js_path, <<~JS)
      //= require react/react.min
      //= require mini-search
      //= require_tree ./ux
    JS

    @migrator.migrate!
    content = File.read(@app_js_path, encoding: "utf-8")

    assert_includes content, "//= require mini-search"
    refute_includes content, "//= require_tree ./ux"
  end

  def test_creates_bak_backup_before_writing
    @migrator.migrate!
    assert File.exist?("#{@app_js_path}.bak")
  end

  def test_backup_contains_original_content
    original = File.read(@app_js_path)
    @migrator.migrate!
    assert_equal original, File.read("#{@app_js_path}.bak")
  end

  def test_removes_require_tree_ux_directive
    @migrator.migrate!
    content = File.read(@app_js_path, encoding: "utf-8")
    refute_includes content, "//= require_tree"
  end

  def test_keeps_vendor_lib_requires
    @migrator.migrate!
    content = File.read(@app_js_path, encoding: "utf-8")
    assert_includes content, "react/react.min"
    assert_includes content, "react/react-dom.min"
    assert_includes content, "react/mui.min"
  end

  def test_adds_managed_by_comment
    @migrator.migrate!
    content = File.read(@app_js_path, encoding: "utf-8")
    assert_includes content, "react-manifest-rails"
  end

  def test_does_not_duplicate_managed_header_on_repeated_migration
    @migrator.migrate!
    @migrator.migrate!
    content = File.read(@app_js_path, encoding: "utf-8")
    assert_equal 1, content.scan("Managed by react-manifest-rails").size
  end

  def test_dry_run_does_not_write_any_files
    original = File.read(@app_js_path)
    ReactManifest.configure { |c| c.dry_run = true }
    ReactManifest::ApplicationMigrator.new(@config).migrate!
    assert_equal original, File.read(@app_js_path)
  end

  def test_dry_run_does_not_create_bak_file
    ReactManifest.configure { |c| c.dry_run = true }
    ReactManifest::ApplicationMigrator.new(@config).migrate!
    refute File.exist?("#{@app_js_path}.bak")
  end

  def test_skips_migration_and_reports_already_clean_for_clean_file
    File.write(@app_js_path, "// Vendor libraries\n//= require react/react.min\n")
    results = @migrator.migrate!
    app_result = results.find { |r| r[:file] == @app_js_path }
    assert_equal :already_clean, app_result[:status]
  end

  def test_leaves_original_file_unchanged_when_rename_raises
    original = File.read(@app_js_path, encoding: "utf-8")
    File.stubs(:rename).raises(Errno::ENOSPC, "No space left on device")

    assert_raises(Errno::ENOSPC) { @migrator.migrate! }

    assert_equal original, File.read(@app_js_path, encoding: "utf-8")
  end

  def test_does_not_leave_tmp_file_when_rename_raises
    File.stubs(:rename).raises(Errno::ENOSPC, "No space left on device")

    assert_raises(Errno::ENOSPC) { @migrator.migrate! }

    assert_empty Dir.glob("#{@app_js_path}.tmp.*")
  end
end
