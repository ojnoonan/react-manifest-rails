require "test_helper"

# rubocop:disable Metrics/ClassLength
class GeneratorRunTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
    @generator.run!
  end

  def output_dir
    @config.abs_manifest_dir
  end

  def read_manifest(name)
    File.read(File.join(output_dir, name), encoding: "utf-8")
  end

  def test_generates_ux_shared_js
    assert File.exist?(File.join(output_dir, "ux_shared.js"))
  end

  def test_generates_ux_notifications_js
    assert File.exist?(File.join(output_dir, "ux_notifications.js"))
  end

  def test_generates_ux_users_js
    assert File.exist?(File.join(output_dir, "ux_users.js"))
  end

  def test_generates_ux_main_js
    assert File.exist?(File.join(output_dir, "ux_main.js"))
  end

  def test_ux_shared_js_includes_shared_component_files
    assert_includes read_manifest("ux_shared.js"), "ux/components/buttons/primary_button"
  end

  def test_ux_shared_js_includes_shared_hook_files
    assert_includes read_manifest("ux_shared.js"), "ux/hooks/use_fetch"
  end

  def test_ux_shared_js_includes_shared_lib_files
    assert_includes read_manifest("ux_shared.js"), "ux/lib/api_helpers"
  end

  def test_does_not_inline_shared_component_files_into_controller_manifests
    ctrl_content = read_manifest("ux_notifications.js")
    refute_includes ctrl_content, "ux/components/"
    refute_includes ctrl_content, "ux/hooks/"
    refute_includes ctrl_content, "ux/lib/"
  end

  def test_ux_notifications_js_requires_notifications_index
    assert_includes read_manifest("ux_notifications.js"), "notifications_index"
  end

  def test_ux_notifications_js_requires_notifications_show
    assert_includes read_manifest("ux_notifications.js"), "notifications_show"
  end

  def test_ux_notifications_js_index_appears_before_show
    content = read_manifest("ux_notifications.js")
    assert content.index("notifications_index") < content.index("notifications_show")
  end

  def test_includes_dependent_controller_files_when_main_uses_component_from_another_app_dir
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    main_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(main_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = <<~JS
      const MainIndex = () => <WidgetHost components={[
        DesignVariableShow,
      ]} />;
    JS
    File.write(main_dir.join("main_index.js.jsx"), main_index_content)

    @generator.run!
    content = read_manifest("ux_main.js")

    assert_includes content, "ux/app/design_variables/design_variable_show"
    assert_includes content, "ux/app/main/main_index"
  end

  def test_does_not_include_unrelated_bundle_when_component_name_collides_with_own_bundle_file
    # "builder" sorts before "users" and defines its own generic "Show" component —
    # this mirrors an app-builder/rvb style tool that defines common CRUD-ish names.
    builder_dir = Rails.root.join("app/assets/javascripts/ux/app/builder")
    users_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(builder_dir)
    FileUtils.mkdir_p(users_dir)

    File.write(builder_dir.join("builder_show.js.jsx"), "const Show = () => <div className=\"builder\" />;\n")
    File.write(builder_dir.join("builder_only_helper.js.jsx"), "const BuilderOnlyHelper = () => <div />;\n")

    # users/ defines its OWN "Show" component in a sibling file and renders it
    # from users_index — an ordinary same-bundle reference, not a cross-app one.
    File.write(users_dir.join("users_show.js.jsx"), "const Show = () => <div className=\"users\" />;\n")
    File.write(users_dir.join("users_index.js.jsx"), "const UsersIndex = () => <Show />;\n")

    @generator.run!
    content = read_manifest("ux_users.js")

    refute_includes content, "ux/app/builder/"
  end

  def test_inlines_always_include_bundle_files_into_controller_manifests
    ReactManifest.configure { |c| c.always_include = ["ux_main"] }

    main_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    users_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(main_dir)
    FileUtils.mkdir_p(users_dir)

    File.write(main_dir.join("main_index.js.jsx"), "const MainIndex = () => <div />;\n")
    File.write(users_dir.join("users_index.js.jsx"), "const UsersIndex = () => <div />;\n")

    @generator.run!
    content = read_manifest("ux_users.js")

    assert_includes content, "ux/app/main/main_index"
    assert_includes content, "ux/app/users/users_index"
  end

  def test_idempotency_does_not_change_file_if_content_unchanged
    mtime_before = File.mtime(File.join(output_dir, "ux_notifications.js"))
    sleep 0.01
    results = @generator.run!
    mtime_after = File.mtime(File.join(output_dir, "ux_notifications.js"))

    unchanged = results.select { |r| r[:status] == :unchanged }
    refute_empty unchanged
    assert_equal mtime_before, mtime_after
  end

  def test_manifest_header_does_not_embed_gem_version
    # The gem version must never appear in generated content: it would make
    # every manifest's digest change on every gem upgrade, forcing a full
    # regeneration of every controller bundle for no functional reason.
    content = read_manifest("ux_notifications.js")
    refute_includes content, ReactManifest::VERSION
  end

  def test_dry_run_does_not_write_any_files
    ReactManifest.configure { |c| c.dry_run = true }
    FileUtils.rm_f(File.join(output_dir, "ux_notifications.js"))

    before_exists = Dir.glob(File.join(output_dir, "ux_notifications.js")).any?
    ReactManifest::Generator.new(@config).run!
    after_exists = Dir.glob(File.join(output_dir, "ux_notifications.js")).any?

    assert_equal before_exists, after_exists
  end

  def test_dry_run_logs_notice_via_rails_logger
    ReactManifest.configure { |c| c.dry_run = true }
    FileUtils.rm_f(File.join(output_dir, "ux_notifications.js"))

    debug_calls = []
    $stdout.stubs(:puts)
    Rails.logger.stubs(:debug).with do |msg|
      debug_calls << msg
      true
    end

    ReactManifest::Generator.new(@config).run!

    assert debug_calls.any? { |m| m.include?("DRY-RUN") }, "Expected a DRY-RUN log message"
    assert debug_calls.any? { |m| m.include?("ux_notifications") }, "Expected ux_notifications in dry-run log"
  end

  def test_pinned_file_is_not_overwritten
    pinned_path = File.join(output_dir, "ux_notifications.js")
    File.write(pinned_path, "// HAND CURATED\n//= require something_special\n")

    results = ReactManifest::Generator.new(@config).run!
    skipped = results.select { |r| r[:status] == :skipped_pinned }
    refute_empty skipped

    assert_includes File.read(pinned_path), "HAND CURATED"
  end

  def test_removes_orphaned_manifest_when_controller_directory_is_deleted
    manifest_path = File.join(output_dir, "ux_notifications.js")
    assert File.exist?(manifest_path)

    FileUtils.rm_rf(Rails.root.join("app/assets/javascripts/ux/app/notifications"))
    results = @generator.run!

    refute File.exist?(manifest_path)
    assert(results.any? { |r| r[:path] == manifest_path && r[:status] == :removed_orphan })
  end

  def test_does_not_remove_pinned_manifest_whose_controller_directory_is_deleted
    manifest_path = File.join(output_dir, "ux_notifications.js")
    File.write(manifest_path, "// HAND CURATED\n//= require something_special\n")

    FileUtils.rm_rf(Rails.root.join("app/assets/javascripts/ux/app/notifications"))
    @generator.run!

    assert File.exist?(manifest_path)
    assert_includes File.read(manifest_path), "HAND CURATED"
  end

  def test_dry_run_does_not_remove_orphaned_manifest
    manifest_path = File.join(output_dir, "ux_notifications.js")
    FileUtils.rm_rf(Rails.root.join("app/assets/javascripts/ux/app/notifications"))

    ReactManifest.configure { |c| c.dry_run = true }
    ReactManifest::Generator.new(@config).run!

    assert File.exist?(manifest_path)
  end

  def test_does_not_touch_application_js
    app_path = File.join(@config.abs_output_dir, "application.js")
    mtime = File.mtime(app_path)
    sleep 0.01
    @generator.run!
    assert_equal mtime, File.mtime(app_path)
  end

  def test_auto_generated_returns_false_for_nonexistent_file
    path = File.join(output_dir, "does_not_exist.js")
    refute @generator.send(:auto_generated?, path)
  end

  def test_auto_generated_returns_false_for_unreadable_file
    path = File.join(output_dir, "ux_shared.js")
    original_foreach = File.method(:foreach)
    File.define_singleton_method(:foreach) do |f, *args, **opts, &blk|
      raise Errno::EACCES, "Permission denied" if f == path

      original_foreach.call(f, *args, **opts, &blk)
    end
    refute @generator.send(:auto_generated?, path)
  ensure
    begin
      File.singleton_class.remove_method(:foreach)
    rescue StandardError
      nil
    end
  end

  def test_cleans_up_temp_file_when_atomic_write_fails
    dest = File.join(output_dir, "ux_notifications.js")
    FileUtils.rm(dest)
    File.stubs(:rename).raises(Errno::EXDEV, "cross-device link")

    assert_raises(Errno::EXDEV) { @generator.run! }

    tmp_files = Dir.glob("#{dest}.tmp.*")
    assert_empty tmp_files
  end

  def test_removes_duplicate_auto_generated_legacy_manifests_from_output_root
    legacy_path   = File.join(@config.abs_output_dir, "ux_shared.js")
    manifest_path = File.join(@config.abs_manifest_dir, "ux_shared.js")

    FileUtils.mkdir_p(@config.abs_manifest_dir)
    File.write(manifest_path, "// AUTO-GENERATED\n//= require ux/components/new_path\n")
    File.write(legacy_path,   "// AUTO-GENERATED\n//= require ux/components/old_path\n")

    ReactManifest::Generator.new(@config).run!

    assert File.exist?(manifest_path)
    refute File.exist?(legacy_path)
  end

  def test_external_providers_includes_require_path_for_symbol_used_in_controller
    ReactManifest.configure { |c| c.external_providers = { "MiniSearch" => "mini-search" } }

    ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js.jsx"),
               "const search = new MiniSearch({ fields: ['name'] });\n")

    @generator.run!
    assert_includes read_manifest("ux_users.js"), "mini-search"
  end

  def test_external_providers_skips_providers_already_in_shared_dirs
    shared_file = Rails.root.join("app/assets/javascripts/ux/lib/fancy_widget.js")
    File.write(shared_file, "const FancyWidget = () => <div />;\n")

    ReactManifest.configure { |c| c.external_providers = { "FancyWidget" => "ux/lib/fancy_widget" } }

    ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js.jsx"),
               "const Page = () => <FancyWidget />;\n")

    @generator.run!
    assert_includes read_manifest("ux_users.js"), "ux/lib/fancy_widget"
  end

  def test_external_roots_includes_files_when_their_symbols_are_used
    ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
    FileUtils.mkdir_p(ext_dir)
    File.write(ext_dir.join("fancy_widget.js"),
               "const FancyWidget = () => <div />;\n")

    ReactManifest.configure { |c| c.external_roots = [ext_dir.to_s] }

    ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js.jsx"),
               "const Page = () => <FancyWidget />;\n")

    @generator.run!
    assert_includes read_manifest("ux_users.js"), "fancy_widget"
  end

  def test_external_roots_skips_files_already_in_shared_dirs
    shared_lib = Rails.root.join("app/assets/javascripts/ux/lib")
    FileUtils.mkdir_p(shared_lib)
    File.write(shared_lib.join("fancy_widget.js"),
               "const FancyWidget = () => <div />;\n")

    ReactManifest.configure { |c| c.external_roots = [shared_lib.to_s] }

    ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js.jsx"),
               "const Page = () => <FancyWidget />;\n")

    @generator.run!
    assert_includes read_manifest("ux_users.js"), "ux/lib/fancy_widget"
  end

  def test_external_roots_warns_when_file_references_controller_only_symbol
    ext_dir = Rails.root.join("app", "assets", "javascripts", "components", "navbar")
    FileUtils.mkdir_p(ext_dir)
    File.write(ext_dir.join("top_nav.js"),
               "const TopNav = () => <UsersIndex />;\n")

    ReactManifest.configure { |c| c.external_roots = [ext_dir.to_s] }

    warn_calls = []
    $stdout.stubs(:puts)
    Rails.logger.stubs(:warn).with do |msg|
      warn_calls << msg
      true
    end
    @generator.run!

    assert(warn_calls.any? do |m|
      m.include?("External file 'components/navbar/top_nav' references controller-only symbol 'UsersIndex'")
    end)
  end

  # TypeScript extension handling (no pre-run setup dependency needed, but present here)

  def test_ts_extension_emits_clean_require_path_for_ts_shared_file
    ReactManifest.configure { |c| c.extensions = %w[js jsx ts tsx] }

    components_dir = Rails.root.join("app", "assets", "javascripts", "ux", "components")
    FileUtils.mkdir_p(components_dir)
    File.write(components_dir.join("ts_widget.ts"), "export const TsWidget = () => {};\n")

    ctrl_dir = Rails.root.join("app", "assets", "javascripts", "ux", "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.tsx"), "const UsersIndex = () => <TsWidget />;\n")

    @generator.run!

    shared_content = read_manifest("ux_shared.js")
    assert_includes shared_content, "//= require ux/components/ts_widget"
    refute_includes shared_content, "ts_widget.ts"
  end

  def test_ts_extension_emits_clean_require_path_for_tsx_shared_file
    ReactManifest.configure { |c| c.extensions = %w[js jsx ts tsx] }

    components_dir = Rails.root.join("app", "assets", "javascripts", "ux", "components")
    FileUtils.mkdir_p(components_dir)
    File.write(components_dir.join("tsx_button.tsx"), "export const TsxButton = () => <button />;\n")

    ctrl_dir = Rails.root.join("app", "assets", "javascripts", "ux", "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.tsx"), "const UsersIndex = () => <TsxButton />;\n")

    @generator.run!

    shared_content = read_manifest("ux_shared.js")
    assert_includes shared_content, "//= require ux/components/tsx_button"
    refute_includes shared_content, "tsx_button.tsx"
  end
end

class GeneratorCleanTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
    FileUtils.mkdir_p(@config.abs_manifest_dir)
  end

  def manifest_dir
    @config.abs_manifest_dir
  end

  def test_clean_removes_auto_generated_manifests_and_returns_count
    File.write(File.join(manifest_dir, "ux_users.js"),
               "// AUTO-GENERATED — DO NOT EDIT\n//= require ux/shared\n")

    result = @generator.clean!

    refute File.exist?(File.join(manifest_dir, "ux_users.js"))
    assert_equal 1, result[:removed]
    assert_equal 0, result[:skipped]
  end

  def test_clean_skips_non_auto_generated_files
    File.write(File.join(manifest_dir, "ux_pinned.js"), "//= require my_custom_thing\n")

    result = @generator.clean!

    assert File.exist?(File.join(manifest_dir, "ux_pinned.js"))
    assert_equal 0, result[:removed]
    assert_equal 1, result[:skipped]
  end

  def test_clean_does_not_raise_when_file_disappears_between_glob_and_read
    path = File.join(manifest_dir, "ux_vanishing.js")
    File.write(path, "// AUTO-GENERATED — DO NOT EDIT\n")

    original_foreach = File.method(:foreach)
    File.define_singleton_method(:foreach) do |f, *args, **opts, &blk|
      File.delete(path) if f == path
      original_foreach.call(f, *args, **opts, &blk)
    end

    @generator.clean!
  ensure
    begin
      File.singleton_class.remove_method(:foreach)
    rescue StandardError
      nil
    end
  end
end
# rubocop:enable Metrics/ClassLength
