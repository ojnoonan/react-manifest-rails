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

    it "generates ux_shared.js" do
      expect(File.exist?(File.join(output_dir, "ux_shared.js"))).to be true
    end

    it "generates ux_notifications.js" do
      expect(File.exist?(File.join(output_dir, "ux_notifications.js"))).to be true
    end

    it "generates ux_users.js" do
      expect(File.exist?(File.join(output_dir, "ux_users.js"))).to be true
    end

    it "generates ux_main.js" do
      expect(File.exist?(File.join(output_dir, "ux_main.js"))).to be true
    end

    describe "ux_shared.js content" do
      subject(:content) { read_manifest("ux_shared.js") }

      it "has the AUTO-GENERATED header" do
        expect(content).to include("AUTO-GENERATED")
      end

      it "requires component files" do
        expect(content).to include("ux/components/buttons/icon_button")
        expect(content).to include("ux/components/buttons/primary_button")
        expect(content).to include("ux/components/form/text_input")
      end

      it "requires hook files" do
        expect(content).to include("ux/hooks/use_fetch")
        expect(content).to include("ux/hooks/use_modal")
      end

      it "requires lib files" do
        expect(content).to include("ux/lib/api_helpers")
        expect(content).to include("ux/lib/format_date")
      end

      it "buttons/ appears before hooks/ (alphabetical order)" do
        btn_pos  = content.index("components/buttons")
        hook_pos = content.index("hooks/")
        expect(btn_pos).to be < hook_pos
      end

      it "icon_button appears before primary_button (alphabetical within dir)" do
        icon_pos    = content.index("icon_button")
        primary_pos = content.index("primary_button")
        expect(icon_pos).to be < primary_pos
      end
    end

    describe "ux_notifications.js content" do
      subject(:content) { read_manifest("ux_notifications.js") }

      it "requires ux_shared" do
        expect(content).to include("//= require ux_shared")
      end

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

    describe "idempotency" do
      it "does not change file if content is unchanged" do
        mtime_before = File.mtime(File.join(output_dir, "ux_shared.js"))
        sleep 0.01
        results = generator.run!
        mtime_after = File.mtime(File.join(output_dir, "ux_shared.js"))

        unchanged = results.select { |r| r[:status] == :unchanged }
        expect(unchanged).not_to be_empty
        expect(mtime_before).to eq(mtime_after)
      end
    end

    describe "dry_run mode" do
      it "does not write any files" do
        ReactManifest.configure { |c| c.dry_run = true }
        FileUtils.rm_f(File.join(output_dir, "ux_shared.js"))

        expect do
          described_class.new(config).run!
        end.not_to(change { Dir.glob(File.join(output_dir, "ux_shared.js")).any? })
      end
    end

    describe "pinned file protection" do
      it "does not overwrite a file without AUTO-GENERATED header" do
        # Write a hand-curated ux_shared.js without the header
        pinned_path = File.join(output_dir, "ux_shared.js")
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
        dest = File.join(output_dir, "ux_shared.js")
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
  end
end
