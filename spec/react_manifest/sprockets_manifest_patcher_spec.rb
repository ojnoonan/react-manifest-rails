require "spec_helper"

RSpec.describe ReactManifest::SprocketsManifestPatcher do
  subject(:patcher) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
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

  describe "#patch!" do
    context "fresh manifest without link_tree" do
      before do
        write_manifest(<<~JS)
          //= link_tree ../images
          //= link_directory ../javascripts .js
          //= link_directory ../stylesheets .css
        JS
      end

      it "returns status :patched" do
        expect(patcher.patch!.status).to eq(:patched)
      end

      it "adds the link_tree directive after the last //= line" do
        patcher.patch!
        content = read_manifest
        lines   = content.lines
        last_directive_idx  = lines.rindex { |l| l.include?("//=") }
        link_tree_idx       = lines.index { |l| l.include?("link_tree") && l.include?("ux_manifests") }
        expect(link_tree_idx).not_to be_nil
        expect(link_tree_idx).to be <= last_directive_idx + 1
      end

      it "does not duplicate the directive on a second patch" do
        patcher.patch!
        patcher.patch!
        count = read_manifest.scan("ux_manifests").size
        expect(count).to eq(1)
      end

      it "reflects the configured manifest_subdir" do
        ReactManifest.configure { |c| c.manifest_subdir = "my_bundles" }
        described_class.new(config).patch!
        expect(read_manifest).to include("my_bundles")
      end
    end

    context "manifest that already has the directive" do
      before do
        write_manifest("//= link_tree ../javascripts/ux_manifests .js\n")
      end

      it "returns status :already_patched" do
        expect(patcher.patch!.status).to eq(:already_patched)
      end

      it "does not modify the file" do
        original = read_manifest
        patcher.patch!
        expect(read_manifest).to eq(original)
      end
    end

    context "manifest.js does not exist" do
      before { FileUtils.rm_f(manifest_path) }

      it "returns status :not_found" do
        expect(patcher.patch!.status).to eq(:not_found)
      end
    end

    context "dry_run mode" do
      before do
        write_manifest("//= link_directory ../javascripts .js\n")
        ReactManifest.configure { |c| c.dry_run = true }
      end

      it "returns status :dry_run" do
        expect(described_class.new(config).patch!.status).to eq(:dry_run)
      end

      it "does not modify the file" do
        original = read_manifest
        described_class.new(config).patch!
        expect(read_manifest).to eq(original)
      end
    end
  end

  describe "#already_patched?" do
    it "returns false when directive is absent" do
      write_manifest("//= link_directory ../javascripts .js\n")
      expect(patcher.already_patched?).to be false
    end

    it "returns true when directive is present" do
      write_manifest("//= link_tree ../javascripts/ux_manifests .js\n")
      expect(patcher.already_patched?).to be true
    end

    it "returns false when manifest.js does not exist" do
      FileUtils.rm_f(manifest_path)
      expect(patcher.already_patched?).to be false
    end
  end
end
