require "spec_helper"

RSpec.describe ReactManifest::ApplicationMigrator do
  subject(:migrator) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  let(:app_js_path) { File.join(config.abs_output_dir, "application.js") }

  describe "#migrate!" do
    it "creates a .bak backup before writing" do
      migrator.migrate!
      expect(File.exist?("#{app_js_path}.bak")).to be true
    end

    it "backup contains the original content" do
      original = File.read(app_js_path)
      migrator.migrate!
      expect(File.read("#{app_js_path}.bak")).to eq(original)
    end

    it "removes //= require_tree ./ux directive from migrated file" do
      migrator.migrate!
      content = File.read(app_js_path, encoding: "utf-8")
      expect(content).not_to include("//= require_tree")
    end

    it "keeps vendor lib requires in migrated file" do
      migrator.migrate!
      content = File.read(app_js_path, encoding: "utf-8")
      expect(content).to include("react/react.min")
      expect(content).to include("react/react-dom.min")
      expect(content).to include("react/mui.min")
    end

    it "adds the managed-by comment" do
      migrator.migrate!
      content = File.read(app_js_path, encoding: "utf-8")
      expect(content).to include("react-manifest-rails")
    end

    describe "dry_run mode" do
      before { ReactManifest.configure { |c| c.dry_run = true } }

      it "does not write any files" do
        original = File.read(app_js_path)
        described_class.new(config).migrate!
        expect(File.read(app_js_path)).to eq(original)
      end

      it "does not create a .bak file" do
        described_class.new(config).migrate!
        expect(File.exist?("#{app_js_path}.bak")).to be false
      end
    end

    describe "already clean file" do
      before do
        File.write(app_js_path, "// Vendor libraries\n//= require react/react.min\n")
      end

      it "skips migration and reports already_clean" do
        results = migrator.migrate!
        app_result = results.find { |r| r[:file] == app_js_path }
        expect(app_result[:status]).to eq(:already_clean)
      end
    end
  end
end
