require "test_helper"

# Shared helper to build the fake view base class used across ViewHelpers tests.
module ViewHelperClassBuilder
  def base_class
    @base_class ||= Class.new do
      def react_component(name, *_args, **_kwargs)
        "<div data-react-component='#{name}'></div>"
      end

      def javascript_include_tag(*names, **_opts)
        names.map { |name| "<script src='#{name}.js'></script>" }.join
      end

      def safe_join(parts)
        parts.join
      end
    end
  end

  def host_class
    @host_class ||= Class.new(base_class) { include ReactManifest::ViewHelpers }
  end

  def host_with_bundle_tag_class
    @host_with_bundle_tag_class ||= Class.new(base_class) do
      include ReactManifest::ViewHelpers

      attr_reader :controller_path

      def initialize(ctrl)
        super()
        @controller_path = ctrl
      end

      def respond_to?(sym, include_private = false) # rubocop:disable Style/OptionalBooleanParameter
        sym == :controller_path || super
      end
    end
  end
end

# Tests for ReactManifest module methods that require manifests to already be generated.
class ReactManifestModuleTest < ReactManifestTest
  include ViewHelperClassBuilder

  def setup
    super
    @config = ReactManifest.configuration
    ReactManifest::Generator.new(@config).run!
  end

  # --- component_maps memoization ---

  def test_tree_classifier_runs_only_once_for_multiple_resolve_calls
    call_count = 0
    original_new = ReactManifest::TreeClassifier.method(:new)
    ReactManifest::TreeClassifier.define_singleton_method(:new) do |*args, &blk|
      call_count += 1
      original_new.call(*args, &blk)
    end

    10.times { ReactManifest.resolve_bundles_for_component_direct("UsersIndex") }

    assert_equal 1, call_count
  ensure
    begin
      ReactManifest::TreeClassifier.singleton_class.remove_method(:new)
    rescue StandardError
      nil
    end
  end

  def test_tree_classifier_reruns_after_reset
    call_count = 0
    original_new = ReactManifest::TreeClassifier.method(:new)
    ReactManifest::TreeClassifier.define_singleton_method(:new) do |*args, &blk|
      call_count += 1
      original_new.call(*args, &blk)
    end

    ReactManifest.resolve_bundles_for_component_direct("UsersIndex")
    ReactManifest.reset!
    fixture_config(@tmpdir)
    ReactManifest.resolve_bundles_for_component_direct("UsersIndex")

    assert_equal 2, call_count
  ensure
    begin
      ReactManifest::TreeClassifier.singleton_class.remove_method(:new)
    rescue StandardError
      nil
    end
  end

  # --- resolve_bundles ---

  def test_resolve_bundles_includes_controller_specific_bundle_when_it_exists
    bundles = ReactManifest.resolve_bundles("notifications")
    assert_includes bundles, "ux_manifests/ux_notifications"
  end

  def test_resolve_bundles_returns_only_shared_for_controller_with_no_jsx
    bundles = ReactManifest.resolve_bundles("sessions")
    refute_includes bundles, "ux_sessions"
  end

  def test_resolve_bundles_includes_always_include_bundles_when_configured
    ReactManifest.configure { |c| c.always_include = ["ux_main"] }
    bundles = ReactManifest.resolve_bundles("notifications")
    assert_includes bundles, "ux_manifests/ux_main"
  end

  def test_resolve_bundles_returns_only_shared_when_no_controller_bundle_and_no_always_include
    ReactManifest.configure { |c| c.always_include = [] }
    bundles = ReactManifest.resolve_bundles("sessions")
    assert_equal %w[ux_manifests/ux_shared], bundles
  end

  def test_resolve_bundles_falls_back_from_ux_admin_users_to_ux_admin
    admin_path = File.join(@config.abs_output_dir, "ux_admin.js")
    File.write(admin_path, "// AUTO-GENERATED\n//= require ux_shared\n")

    bundles = ReactManifest.resolve_bundles("admin/users")
    assert_includes bundles, "ux_admin"
    refute_includes bundles, "ux_admin_users"
  end

  def test_resolve_bundles_prefers_ux_admin_users_over_ux_admin_when_both_exist
    admin_users_path = File.join(@config.abs_output_dir, "ux_admin_users.js")
    admin_path       = File.join(@config.abs_output_dir, "ux_admin.js")
    File.write(admin_users_path, "// AUTO-GENERATED\n//= require ux_shared\n")
    File.write(admin_path,       "// AUTO-GENERATED\n//= require ux_shared\n")

    bundles = ReactManifest.resolve_bundles("admin/users")
    assert_includes bundles, "ux_admin_users"
  end

  def test_resolve_bundles_tries_leaf_segment_for_deeply_nested_controllers
    reports_path = File.join(@config.abs_output_dir, "ux_reports.js")
    File.write(reports_path, "// AUTO-GENERATED\n//= require ux_shared\n")

    bundles = ReactManifest.resolve_bundles("admin/dashboard/reports")
    assert_includes bundles, "ux_reports"
  end

  def test_resolve_bundles_returns_only_shared_for_empty_string_controller
    bundles = ReactManifest.resolve_bundles("")
    assert_equal %w[ux_manifests/ux_shared], bundles
  end

  def test_resolve_bundles_does_not_include_nonexistent_bundle
    bundles = ReactManifest.resolve_bundles("ghost_controller")
    refute_includes bundles, "ux_ghost_controller"
  end

  # --- resolve_bundle_for_component ---

  def test_resolve_bundle_for_component_maps_known_controller_component_to_bundle
    assert_equal "ux_manifests/ux_users", ReactManifest.resolve_bundle_for_component("UsersIndex")
  end

  def test_resolve_bundle_for_component_returns_nil_for_unknown_symbol
    assert_nil ReactManifest.resolve_bundle_for_component("UserSignInForm")
  end

  def test_resolve_bundle_for_component_returns_nil_for_blank_name
    assert_nil ReactManifest.resolve_bundle_for_component("")
  end

  def test_resolve_bundle_for_component_maps_symbol_from_non_controller_aligned_dir
    dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
    FileUtils.mkdir_p(dir)
    File.write(dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal "ux_manifests/ux_user_session",
                 ReactManifest.resolve_bundle_for_component("UserSignInForm")
  end

  # --- resolve_bundles_for_component ---

  def test_resolve_bundles_for_component_includes_dependent_controller_bundles
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/account")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")
    File.write(app_dir.join("account_show.js.jsx"), "const AccountShow = () => <UserSignInForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_user_session ux_manifests/ux_account],
                 ReactManifest.resolve_bundles_for_component("AccountShow")
  end

  def test_resolve_bundles_for_component_resolves_cross_controller_dependencies
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"), "const MainIndex = () => <DesignVariableShow />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_design_variables ux_manifests/ux_main],
                 ReactManifest.resolve_bundles_for_component("MainIndex")
  end

  def test_resolve_bundles_for_component_resolves_component_passed_as_jsx_prop
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost contentComponent={DesignVariableShow} />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_design_variables ux_manifests/ux_main],
                 ReactManifest.resolve_bundles_for_component("MainIndex")
  end

  def test_resolve_bundles_for_component_resolves_component_passed_as_object_value
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost options={{ component: DesignVariableShow }} />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_design_variables ux_manifests/ux_main],
                 ReactManifest.resolve_bundles_for_component("MainIndex")
  end

  def test_resolve_bundles_for_component_resolves_components_in_arrays
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost components={[DesignVariableShow]} />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_design_variables ux_manifests/ux_main],
                 ReactManifest.resolve_bundles_for_component("MainIndex")
  end

  def test_resolve_bundles_for_component_resolves_array_components_on_separate_lines
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"), <<~JS)
      const MainIndex = () => <WidgetHost components={[
        DesignVariableShow,
      ]} />;
    JS

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_design_variables ux_manifests/ux_main],
                 ReactManifest.resolve_bundles_for_component("MainIndex")
  end

  # --- resolve_bundles_for_component_direct ---

  def test_resolve_bundles_for_component_direct_returns_shared_and_direct_bundle
    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_shared ux_manifests/ux_users],
                 ReactManifest.resolve_bundles_for_component_direct("UsersIndex")
  end

  def test_resolve_bundles_for_component_direct_does_not_include_transitive_deps
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/account")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")
    File.write(app_dir.join("account_show.js.jsx"), "const AccountShow = () => <UserSignInForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_equal %w[ux_manifests/ux_shared ux_manifests/ux_account],
                 ReactManifest.resolve_bundles_for_component_direct("AccountShow")
  end
end

# Tests for the ReactManifest::ViewHelpers module mixed into a view-like object.
class ViewHelpersTest < ReactManifestTest
  include ViewHelperClassBuilder

  def setup
    super
    @config = ReactManifest.configuration
    ReactManifest::Generator.new(@config).run!
  end

  def test_prepends_resolved_ux_bundle_when_rendering_react_component
    html = host_class.new.react_component("UsersIndex")
    assert_includes html, "ux_users.js"
    assert_includes html, "data-react-component='UsersIndex'"
  end

  def test_does_not_duplicate_component_bundle_for_repeated_calls
    view = host_class.new
    first  = view.react_component("UsersIndex")
    second = view.react_component("UsersIndex")

    assert_includes first, "ux_users.js"
    refute_includes second, "ux_users.js"
  end

  def test_injects_only_direct_bundle_for_cross_controller_component_usage
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/account")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")
    File.write(app_dir.join("account_show.js.jsx"), "const AccountShow = () => <UserSignInForm />;\n")

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("AccountShow")
    assert_includes html, "ux_account.js"
    refute_includes html, "ux_user_session.js"
  end

  def test_injects_only_direct_bundle_when_main_uses_design_variable_show
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"), "const MainIndex = () => <DesignVariableShow />;\n")

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("MainIndex")
    assert_includes html, "ux_main.js"
    refute_includes html, "ux_design_variables.js"
  end

  def test_injects_only_direct_bundle_when_component_passed_as_jsx_prop
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost contentComponent={DesignVariableShow} />;\n")

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("MainIndex")
    assert_includes html, "ux_main.js"
    refute_includes html, "ux_design_variables.js"
  end

  def test_injects_only_direct_bundle_when_component_passed_as_object_value
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost options={{ component: DesignVariableShow }} />;\n")

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("MainIndex")
    assert_includes html, "ux_main.js"
    refute_includes html, "ux_design_variables.js"
  end

  def test_injects_only_direct_bundle_when_components_passed_in_arrays
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"),
               "const MainIndex = () => <WidgetHost components={[DesignVariableShow]} />;\n")

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("MainIndex")
    assert_includes html, "ux_main.js"
    refute_includes html, "ux_design_variables.js"
  end

  def test_injects_only_direct_bundle_when_array_components_on_separate_lines
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"), <<~JS)
      const MainIndex = () => <WidgetHost components={[
        DesignVariableShow,
      ]} />;
    JS

    ReactManifest::Generator.new(@config).run!

    html = host_class.new.react_component("MainIndex")
    assert_includes html, "ux_main.js"
    refute_includes html, "ux_design_variables.js"
  end

  def test_react_bundle_tag_and_react_component_do_not_re_emit_shared_bundles
    view = host_with_bundle_tag_class.new("users")

    bundle_html = view.react_bundle_tag
    assert_includes bundle_html, "ux_users.js"

    component_html = view.react_component("UsersIndex")
    refute_includes component_html, "ux_users.js"
    assert_includes component_html, "data-react-component='UsersIndex'"
  end
end
