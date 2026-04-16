require "spec_helper"

RSpec.describe ReactManifest do
  describe ".resolve_bundles" do
    around(:each) do |example|
      with_temp_rails_root do |tmpdir|
        copy_fixtures_to(tmpdir)
        fixture_config(tmpdir)
        # Pre-generate manifests so bundles exist
        ReactManifest::Generator.new(ReactManifest.configuration).run!
        example.run
      end
    end

    let(:config) { ReactManifest.configuration }

    it "always includes the shared bundle" do
      bundles = described_class.resolve_bundles("notifications")
      expect(bundles).to include("ux_manifests/ux_shared")
    end

    it "includes the controller-specific bundle when it exists" do
      bundles = described_class.resolve_bundles("notifications")
      expect(bundles).to include("ux_manifests/ux_notifications")
    end

    it "shared bundle comes before controller bundle" do
      bundles = described_class.resolve_bundles("notifications")
      shared_idx = bundles.index("ux_manifests/ux_shared")
      ctrl_idx   = bundles.index("ux_manifests/ux_notifications")
      expect(shared_idx).to be < ctrl_idx
    end

    it "returns only shared bundles for a pure ERB controller with no JSX" do
      bundles = described_class.resolve_bundles("sessions")
      expect(bundles).not_to include("ux_sessions")
    end

    it "includes always_include bundles when configured" do
      ReactManifest.configure { |c| c.always_include = ["ux_main"] }
      bundles = described_class.resolve_bundles("notifications")
      expect(bundles).to include("ux_manifests/ux_main")
    end

    it "returns empty array when no shared bundle and no match (zero-JS page)" do
      ReactManifest.configure do |c|
        c.shared_bundle  = "nonexistent_bundle"
        c.always_include = []
      end
      bundles = described_class.resolve_bundles("sessions")
      expect(bundles).to be_empty
    end

    describe "namespaced controllers" do
      it "falls back from ux_admin_users to ux_admin when only ux_admin exists" do
        # Create a fake ux_admin.js with AUTO-GENERATED header
        admin_path = File.join(config.abs_output_dir, "ux_admin.js")
        File.write(admin_path, "// AUTO-GENERATED\n//= require ux_shared\n")

        bundles = described_class.resolve_bundles("admin/users")
        expect(bundles).to include("ux_admin")
        expect(bundles).not_to include("ux_admin_users")
      end

      it "prefers ux_admin_users over ux_admin when both exist" do
        admin_users_path = File.join(config.abs_output_dir, "ux_admin_users.js")
        admin_path       = File.join(config.abs_output_dir, "ux_admin.js")
        File.write(admin_users_path, "// AUTO-GENERATED\n//= require ux_shared\n")
        File.write(admin_path,       "// AUTO-GENERATED\n//= require ux_shared\n")

        bundles = described_class.resolve_bundles("admin/users")
        expect(bundles).to include("ux_admin_users")
      end

      it "also tries the leaf segment for deeply nested controllers" do
        # admin/dashboard/reports → should fall back to ux_reports if that exists
        reports_path = File.join(config.abs_output_dir, "ux_reports.js")
        File.write(reports_path, "// AUTO-GENERATED\n//= require ux_shared\n")

        bundles = described_class.resolve_bundles("admin/dashboard/reports")
        expect(bundles).to include("ux_reports")
      end
    end

    describe "edge cases" do
      it "returns only shared bundle for an empty string controller" do
        bundles = described_class.resolve_bundles("")
        # ux_ exists if generator made one; otherwise just shared
        expect(bundles).to include("ux_manifests/ux_shared")
      end

      it "does not duplicate shared bundle in always_include" do
        ReactManifest.configure { |c| c.always_include = [config.shared_bundle] }
        bundles = described_class.resolve_bundles("notifications")
        expect(bundles.count("ux_manifests/#{config.shared_bundle}")).to eq(1)
      end

      it "does not include a bundle that does not exist on disk" do
        bundles = described_class.resolve_bundles("ghost_controller")
        expect(bundles).not_to include("ux_ghost_controller")
      end
    end
  end

  describe ".resolve_bundle_for_component" do
    around(:each) do |example|
      with_temp_rails_root do |tmpdir|
        copy_fixtures_to(tmpdir)
        fixture_config(tmpdir)
        ReactManifest::Generator.new(ReactManifest.configuration).run!
        example.run
      end
    end

    it "maps a known controller component symbol to its ux bundle" do
      expect(described_class.resolve_bundle_for_component("UsersIndex")).to eq("ux_manifests/ux_users")
    end

    it "returns nil for unknown component symbols" do
      expect(described_class.resolve_bundle_for_component("UserSignInForm")).to be_nil
    end

    it "returns nil for blank component names" do
      expect(described_class.resolve_bundle_for_component("")).to be_nil
    end

    it "maps component symbols from non-controller-aligned ux dirs" do
      dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
      FileUtils.mkdir_p(dir)
      File.write(dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundle_for_component("UserSignInForm")).to eq("ux_manifests/ux_user_session")
    end
  end

  describe ".resolve_bundles_for_component" do
    around(:each) do |example|
      with_temp_rails_root do |tmpdir|
        copy_fixtures_to(tmpdir)
        fixture_config(tmpdir)
        example.run
      end
    end

    it "includes dependent controller bundles used by a component" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/account")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")
      File.write(app_dir.join("account_show.js.jsx"), "const AccountShow = () => <UserSignInForm />;\n")

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("AccountShow"))
        .to eq(%w[ux_manifests/ux_user_session ux_manifests/ux_account])
    end

    it "resolves cross-controller dependencies for main pages" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
      File.write(app_dir.join("main_index.js.jsx"), "const MainIndex = () => <DesignVariableShow />;\n")

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("MainIndex"))
        .to eq(%w[ux_manifests/ux_design_variables ux_manifests/ux_main])
    end

    it "resolves dependencies when a component is passed via JSX props" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
      main_index_content = "const MainIndex = () => <WidgetHost contentComponent={DesignVariableShow} />;\n"
      File.write(app_dir.join("main_index.js.jsx"), main_index_content)

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("MainIndex"))
        .to eq(%w[ux_manifests/ux_design_variables ux_manifests/ux_main])
    end

    it "resolves dependencies when a component is passed as an object value" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
      main_index_content = "const MainIndex = () => <WidgetHost options={{ component: DesignVariableShow }} />;\n"
      File.write(app_dir.join("main_index.js.jsx"), main_index_content)

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("MainIndex"))
        .to eq(%w[ux_manifests/ux_design_variables ux_manifests/ux_main])
    end

    it "resolves dependencies when components are passed in arrays" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
      main_index_content = "const MainIndex = () => <WidgetHost components={[DesignVariableShow]} />;\n"
      File.write(app_dir.join("main_index.js.jsx"), main_index_content)

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("MainIndex"))
        .to eq(%w[ux_manifests/ux_design_variables ux_manifests/ux_main])
    end

    it "resolves dependencies when array components are on separate lines" do
      dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
      app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      FileUtils.mkdir_p(dep_dir)
      FileUtils.mkdir_p(app_dir)

      File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
      main_index_content = <<~JS
        const MainIndex = () => <WidgetHost components={[
          DesignVariableShow,
        ]} />;
      JS
      File.write(app_dir.join("main_index.js.jsx"), main_index_content)

      ReactManifest::Generator.new(ReactManifest.configuration).run!

      expect(described_class.resolve_bundles_for_component("MainIndex"))
        .to eq(%w[ux_manifests/ux_design_variables ux_manifests/ux_main])
    end
  end
end

RSpec.describe ReactManifest::ViewHelpers do
  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      ReactManifest::Generator.new(ReactManifest.configuration).run!
      example.run
    end
  end

  let(:base_class) do
    Class.new do
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

  let(:host_class) do
    Class.new(base_class) do
      include ReactManifest::ViewHelpers
    end
  end

  it "prepends a resolved ux bundle when rendering react_component" do
    html = host_class.new.react_component("UsersIndex")
    expect(html).to include("ux_users.js")
    expect(html).to include("data-react-component='UsersIndex'")
  end

  it "does not duplicate the same component bundle for repeated calls" do
    view = host_class.new
    first = view.react_component("UsersIndex")
    second = view.react_component("UsersIndex")

    expect(first).to include("ux_users.js")
    expect(second).not_to include("ux_users.js")
  end

  it "injects dependency bundles for cross-controller component usage" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/user_session")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/account")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("user_sign_in_form.js.jsx"), "const UserSignInForm = () => <div />;\n")
    File.write(app_dir.join("account_show.js.jsx"), "const AccountShow = () => <UserSignInForm />;\n")

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("AccountShow")
    expect(html).to include("ux_user_session.js")
    expect(html).to include("ux_account.js")
  end

  it "injects design-variables bundle when MainIndex uses DesignVariableShow" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    File.write(app_dir.join("main_index.js.jsx"), "const MainIndex = () => <DesignVariableShow />;\n")

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("MainIndex")
    expect(html).to include("ux_design_variables.js")
    expect(html).to include("ux_main.js")
  end

  it "injects dependency bundle when component is passed as JSX prop" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = "const MainIndex = () => <WidgetHost contentComponent={DesignVariableShow} />;\n"
    File.write(app_dir.join("main_index.js.jsx"), main_index_content)

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("MainIndex")
    expect(html).to include("ux_design_variables.js")
    expect(html).to include("ux_main.js")
  end

  it "injects dependency bundle when component is passed as object value" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = "const MainIndex = () => <WidgetHost options={{ component: DesignVariableShow }} />;\n"
    File.write(app_dir.join("main_index.js.jsx"), main_index_content)

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("MainIndex")
    expect(html).to include("ux_design_variables.js")
    expect(html).to include("ux_main.js")
  end

  it "injects dependency bundle when components are passed in arrays" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = "const MainIndex = () => <WidgetHost components={[DesignVariableShow]} />;\n"
    File.write(app_dir.join("main_index.js.jsx"), main_index_content)

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("MainIndex")
    expect(html).to include("ux_design_variables.js")
    expect(html).to include("ux_main.js")
  end

  it "injects dependency bundle when array components are on separate lines" do
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    app_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(app_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = <<~JS
      const MainIndex = () => <WidgetHost components={[
        DesignVariableShow,
      ]} />;
    JS
    File.write(app_dir.join("main_index.js.jsx"), main_index_content)

    ReactManifest::Generator.new(ReactManifest.configuration).run!

    html = host_class.new.react_component("MainIndex")
    expect(html).to include("ux_design_variables.js")
    expect(html).to include("ux_main.js")
  end

  describe "react_bundle_tag + react_component deduplication" do
    let(:host_with_bundle_tag) do
      Class.new(base_class) do
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

    it "does not re-emit bundles already loaded by react_bundle_tag" do
      view = host_with_bundle_tag.new("users")

      bundle_html = view.react_bundle_tag
      expect(bundle_html).to include("ux_shared.js")
      expect(bundle_html).to include("ux_users.js")

      component_html = view.react_component("UsersIndex")
      expect(component_html).not_to include("ux_users.js"),
                                    "react_component should not re-emit bundles already loaded by react_bundle_tag"
      expect(component_html).to include("data-react-component='UsersIndex'")
    end
  end
end
