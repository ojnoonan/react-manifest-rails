require "spec_helper"

RSpec.describe ReactManifest::TreeClassifier do
  subject(:classifier) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  describe "#classify" do
    it "identifies controller dirs under ux/app/" do
      result = classifier.classify
      names = result.controller_dirs.map { |d| d[:name] }
      expect(names).to include("notifications", "users", "main")
    end

    it "identifies shared dirs (components, hooks, lib)" do
      result = classifier.classify
      names = result.shared_dirs.map { |d| d[:name] }
      expect(names).to include("components", "hooks", "lib")
    end

    it "does NOT include shared dirs as controller dirs" do
      result = classifier.classify
      ctrl_names = result.controller_dirs.map { |d| d[:name] }
      expect(ctrl_names).not_to include("components", "hooks", "lib")
    end

    it "assigns correct bundle_name to each controller dir" do
      result = classifier.classify
      notif = result.controller_dirs.find { |d| d[:name] == "notifications" }
      expect(notif[:bundle_name]).to eq("ux_notifications")
    end

    it "auto-discovers a new shared dir added at runtime" do
      new_dir = File.join(Rails.root.join(config.ux_root).to_s, "contexts")
      FileUtils.mkdir_p(new_dir)

      result = classifier.classify
      names = result.shared_dirs.map { |d| d[:name] }
      expect(names).to include("contexts")
    end

    it "respects the ignore list for controller dirs" do
      ReactManifest.configure { |c| c.ignore = ["notifications"] }
      result = classifier.classify
      names = result.controller_dirs.map { |d| d[:name] }
      expect(names).not_to include("notifications")
    end

    it "returns empty results if ux_root does not exist" do
      ReactManifest.configure { |c| c.ux_root = "app/assets/javascripts/nonexistent" }
      result = classifier.classify
      expect(result.controller_dirs).to be_empty
      expect(result.shared_dirs).to be_empty
    end
  end

  describe "#watched_dirs" do
    it "returns paths that exist" do
      dirs = classifier.watched_dirs
      dirs.each { |d| expect(Dir.exist?(d)).to be true }
    end

    it "includes the app dir and shared dirs" do
      dirs = classifier.watched_dirs
      expect(dirs.any? { |d| d.end_with?("/app") }).to be true
    end
  end
end
