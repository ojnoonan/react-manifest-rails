require "spec_helper"

RSpec.describe ReactManifest::Configuration do
  subject(:config) { described_class.new }

  around(:each) do |example|
    with_temp_rails_root { example.run }
  end

  describe "defaults" do
    it "sets ux_root" do
      expect(config.ux_root).to eq("app/assets/javascripts/ux")
    end

    it "sets app_dir" do
      expect(config.app_dir).to eq("app")
    end

    it "sets output_dir" do
      expect(config.output_dir).to eq("app/assets/javascripts")
    end

    it "sets manifest_subdir" do
      expect(config.manifest_subdir).to eq("ux_manifests")
    end

    it "sets shared_bundle" do
      expect(config.shared_bundle).to eq("ux_shared")
    end

    it "sets always_include to empty array" do
      expect(config.always_include).to eq([])
    end

    it "sets ignore to empty array" do
      expect(config.ignore).to eq([])
    end

    it "sets default exclude_paths" do
      expect(config.exclude_paths).to include("vendor", "react")
    end

    it "sets size_threshold_kb to 500" do
      expect(config.size_threshold_kb).to eq(500)
    end

    it "sets extensions to js and jsx" do
      expect(config.extensions).to eq(%w[js jsx])
    end

    it "disables dry_run by default" do
      expect(config.dry_run?).to be false
    end

    it "disables verbose by default" do
      expect(config.verbose?).to be false
    end

    it "enables stdout_logging by default" do
      expect(config.stdout_logging?).to be true
    end
  end

  describe "#abs_ux_root" do
    it "returns absolute path under Rails.root" do
      expect(config.abs_ux_root).to start_with(Rails.root.to_s)
      expect(config.abs_ux_root).to end_with("app/assets/javascripts/ux")
    end
  end

  describe "#abs_output_dir" do
    it "returns absolute path under Rails.root" do
      expect(config.abs_output_dir).to start_with(Rails.root.to_s)
      expect(config.abs_output_dir).to end_with("app/assets/javascripts")
    end
  end

  describe "#abs_manifest_dir" do
    it "returns absolute manifest directory under output_dir" do
      expect(config.abs_manifest_dir).to start_with(Rails.root.to_s)
      expect(config.abs_manifest_dir).to end_with("app/assets/javascripts/ux_manifests")
    end
  end

  describe "#abs_app_dir" do
    it "returns absolute path joining ux_root and app_dir" do
      expect(config.abs_app_dir).to eq(File.join(config.abs_ux_root, config.app_dir))
    end
  end

  describe "#extensions_glob" do
    it "returns glob fragment for default extensions" do
      expect(config.extensions_glob).to eq("*.{js,jsx}")
    end

    it "reflects custom extensions" do
      config.extensions = %w[js jsx ts tsx]
      expect(config.extensions_glob).to eq("*.{js,jsx,ts,tsx}")
    end
  end

  describe "#extensions_pattern" do
    it "returns a Regexp matching default extensions" do
      expect(config.extensions_pattern).to match("foo.js")
      expect(config.extensions_pattern).to match("foo.jsx")
      expect(config.extensions_pattern).not_to match("foo.ts")
    end

    it "reflects custom extensions" do
      config.extensions = %w[js jsx ts tsx]
      expect(config.extensions_pattern).to match("foo.ts")
      expect(config.extensions_pattern).to match("foo.tsx")
    end
  end

  describe "dry_run?" do
    it "returns true when dry_run is set" do
      config.dry_run = true
      expect(config.dry_run?).to be true
    end
  end

  describe "verbose?" do
    it "returns true when verbose is set" do
      config.verbose = true
      expect(config.verbose?).to be true
    end
  end

  describe "stdout_logging?" do
    it "returns true when stdout_logging is set" do
      config.stdout_logging = true
      expect(config.stdout_logging?).to be true
    end

    it "returns false when stdout_logging is disabled" do
      config.stdout_logging = false
      expect(config.stdout_logging?).to be false
    end
  end
end
