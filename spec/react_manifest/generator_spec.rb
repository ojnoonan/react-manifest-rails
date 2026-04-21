require "spec_helper"

RSpec.describe ReactManifest::Generator do
  subject(:generator) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  def output_dir
    config.abs_manifest_dir
  end

  def read_manifest(name)
    File.read(File.join(output_dir, name), encoding: "utf-8")
  end

  describe "#run!" do
    before { generator.run! }

    it "generates ux_notifications.js" do
      expect(File.exist?(File.join(output_dir, "ux_notifications.js"))).to be true
    end

    it "generates ux_users.js" do
      expect(File.exist?(File.join(output_dir, "ux_users.js"))).to be true
    end

    it "generates ux_main.js" do
      expect(File.exist?(File.join(output_dir, "ux_main.js"))).to be true
    end

    describe "ux_notifications.js content" do
      subject(:content) { read_manifest("ux_notifications.js") }

      it "requires notifications_index" do
        expect(content).to include("notifications_index")
      end

      it "requires notifications_show" do
        expect(content).to include("notifications_show")
      end

      it "index appears before show (alphabetical)" do
        idx_pos  = content.index("notifications_index")
        show_pos = content.index("notifications_show")
        expect(idx_pos).to be < show_pos
      end
    end

    it "includes dependent controller files when main uses a component from another app dir" do
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

      generator.run!
      content = read_manifest("ux_main.js")

      expect(content).to include("ux/app/design_variables/design_variable_show")
      expect(content).to include("ux/app/main/main_index")
    end

    it "inlines always_include bundle files into controller manifests" do
      ReactManifest.configure do |c|
        c.always_include = ["ux_main"]
      end

      main_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
      users_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
      FileUtils.mkdir_p(main_dir)
      FileUtils.mkdir_p(users_dir)

      File.write(main_dir.join("main_index.js.jsx"), "const MainIndex = () => <div />;\n")
      File.write(users_dir.join("users_index.js.jsx"), "const UsersIndex = () => <div />;\n")

      generator.run!
      content = read_manifest("ux_users.js")

      expect(content).to include("ux/app/main/main_index")
      expect(content).to include("ux/app/users/users_index")
    end

    describe "idempotency" do
      it "does not change file if content is unchanged" do
        mtime_before = File.mtime(File.join(output_dir, "ux_notifications.js"))
        sleep 0.01
        results = generator.run!
        mtime_after = File.mtime(File.join(output_dir, "ux_notifications.js"))

        unchanged = results.select { |r| r[:status] == :unchanged }
        expect(unchanged).not_to be_empty
        expect(mtime_before).to eq(mtime_after)
      end
    end

    describe "dry_run mode" do
      it "does not write any files" do
        ReactManifest.configure { |c| c.dry_run = true }
        FileUtils.rm_f(File.join(output_dir, "ux_notifications.js"))

        expect do
          described_class.new(config).run!
        end.not_to(change { Dir.glob(File.join(output_dir, "ux_notifications.js")).any? })
      end
    end

    describe "pinned file protection" do
      it "does not overwrite a file without AUTO-GENERATED header" do
        # Write a hand-curated ux_notifications.js without the header
        pinned_path = File.join(output_dir, "ux_notifications.js")
        File.write(pinned_path, "// HAND CURATED\n//= require something_special\n")

        results = described_class.new(config).run!
        skipped = results.select { |r| r[:status] == :skipped_pinned }
        expect(skipped).not_to be_empty

        # Content should remain unchanged
        expect(File.read(pinned_path)).to include("HAND CURATED")
      end
    end

    it "does not touch application.js" do
      app_path = File.join(config.abs_output_dir, "application.js")
      mtime = File.mtime(app_path)
      sleep 0.01
      generator.run!
      expect(File.mtime(app_path)).to eq(mtime)
    end

    describe "error handling" do
      it "returns false from auto_generated? for a nonexistent file" do
        path = File.join(output_dir, "does_not_exist.js")
        expect(generator.send(:auto_generated?, path)).to be false
      end

      it "returns false from auto_generated? for an unreadable file" do
        path = File.join(output_dir, "ux_shared.js")
        allow(File).to receive(:foreach).and_call_original
        allow(File).to receive(:foreach).with(path).and_raise(Errno::EACCES, "Permission denied")
        expect(generator.send(:auto_generated?, path)).to be false
      end

      it "cleans up the temp file when an atomic write fails" do
        dest = File.join(output_dir, "ux_notifications.js")
        # Remove the manifest so write_manifest actually attempts a rename
        FileUtils.rm(dest)

        allow(File).to receive(:rename).and_raise(Errno::EXDEV, "cross-device link")

        expect { generator.run! }.to raise_error(Errno::EXDEV)

        # No stale .tmp.PID file should remain
        tmp_files = Dir.glob("#{dest}.tmp.*")
        expect(tmp_files).to be_empty
      end
    end

    describe "legacy manifest migration" do
      it "removes duplicate auto-generated legacy manifests from output root" do
        legacy_path = File.join(config.abs_output_dir, "ux_shared.js")
        manifest_path = File.join(config.abs_manifest_dir, "ux_shared.js")

        FileUtils.mkdir_p(config.abs_manifest_dir)
        File.write(manifest_path, "// AUTO-GENERATED\n//= require ux/components/new_path\n")
        File.write(legacy_path, "// AUTO-GENERATED\n//= require ux/components/old_path\n")

        described_class.new(config).run!

        expect(File.exist?(manifest_path)).to be true
        expect(File.exist?(legacy_path)).to be false
      end
    end

    describe "external_providers integration" do
      it "includes the require path for an external provider symbol used in a controller" do
        ReactManifest.configure do |c|
          c.external_providers = { "MiniSearch" => "mini-search" }
        end

        ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js.jsx"),
                   "const search = new MiniSearch({ fields: ['name'] });\n")

        generator.run!
        content = read_manifest("ux_users.js")

        expect(content).to include("mini-search")
      end

      it "skips external providers that point at files already in shared dirs" do
        shared_file = Rails.root.join("app/assets/javascripts/ux/lib/fancy_widget.js")
        File.write(shared_file, "const FancyWidget = () => <div />;\n")

        ReactManifest.configure do |c|
          c.external_providers = { "FancyWidget" => "ux/lib/fancy_widget" }
        end

        ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js.jsx"),
                   "const Page = () => <FancyWidget />;\n")

        generator.run!
        content = read_manifest("ux_users.js")

        expect(content).to include("ux/lib/fancy_widget")
      end
    end

    describe "external_roots integration" do
      it "includes files from external_roots when their symbols are used" do
        ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
        FileUtils.mkdir_p(ext_dir)
        File.write(ext_dir.join("fancy_widget.js"),
                   "const FancyWidget = () => <div />;\n")

        ReactManifest.configure do |c|
          c.external_roots = [ext_dir.to_s]
        end

        ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js.jsx"),
                   "const Page = () => <FancyWidget />;\n")

        generator.run!
        content = read_manifest("ux_users.js")

        expect(content).to include("fancy_widget")
      end

      it "skips external_roots files that are already in shared dirs" do
        shared_lib = Rails.root.join("app/assets/javascripts/ux/lib")
        FileUtils.mkdir_p(shared_lib)
        File.write(shared_lib.join("fancy_widget.js"),
                   "const FancyWidget = () => <div />;\n")

        ReactManifest.configure do |c|
          c.external_roots = [shared_lib.to_s]
        end

        ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js.jsx"),
                   "const Page = () => <FancyWidget />;\n")

        generator.run!
        content = read_manifest("ux_users.js")

        expect(content).to include("ux/lib/fancy_widget")
      end

      it "warns when an external_roots file references a controller-only ux/app symbol" do
        ext_dir = Rails.root.join("app", "assets", "javascripts", "components", "navbar")
        FileUtils.mkdir_p(ext_dir)
        File.write(ext_dir.join("top_nav.js"),
                   "const TopNav = () => <UsersIndex />;\n")

        ReactManifest.configure do |c|
          c.external_roots = [ext_dir.to_s]
        end

        allow(generator).to receive(:warn)
        generator.run!

        expect(generator).to have_received(:warn).with(
          include("External file 'components/navbar/top_nav' references controller-only symbol 'UsersIndex'")
        )
      end
    end
  end
end
