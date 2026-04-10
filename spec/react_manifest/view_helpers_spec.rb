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
      expect(bundles).to include("ux_shared")
    end

    it "includes the controller-specific bundle when it exists" do
      bundles = described_class.resolve_bundles("notifications")
      expect(bundles).to include("ux_notifications")
    end

    it "shared bundle comes before controller bundle" do
      bundles = described_class.resolve_bundles("notifications")
      shared_idx = bundles.index("ux_shared")
      ctrl_idx   = bundles.index("ux_notifications")
      expect(shared_idx).to be < ctrl_idx
    end

    it "returns only shared bundles for a pure ERB controller with no JSX" do
      bundles = described_class.resolve_bundles("sessions")
      expect(bundles).not_to include("ux_sessions")
    end

    it "includes always_include bundles when configured" do
      ReactManifest.configure { |c| c.always_include = ["ux_main"] }
      bundles = described_class.resolve_bundles("notifications")
      expect(bundles).to include("ux_main")
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
    end
  end
end
