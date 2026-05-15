require "spec_helper"
require "support/stress_fixture_builder"

RSpec.describe "Stress: deep namespace nesting (3 levels)", :stress do
  around(:each) do |example|
    Dir.mktmpdir("react_manifest_stress") do |tmpdir|
      Rails.root = tmpdir
      ReactManifest.reset!
      StressFixtureBuilder.build_deep_nesting(tmpdir)
      StressFixtureBuilder.configure_for(tmpdir)
      example.run
    end
  end

  let(:config)    { ReactManifest.configuration }
  let(:generator) { ReactManifest::Generator.new(config) }

  it "generates a top-level manifest for the admin controller" do
    generator.run!
    path = File.join(config.abs_manifest_dir, "ux_admin.js")
    expect(File.exist?(path)).to be true
  end

  it "admin manifest recursively includes files from all sub-levels" do
    generator.run!
    content = File.read(File.join(config.abs_manifest_dir, "ux_admin.js"))
    expect(content).to include("//= require ux/app/admin/reports/summary/summary_index")
    expect(content).to include("//= require ux/app/admin/reports/summary/summary_show")
  end

  it "admin manifest carries the AUTO-GENERATED header" do
    generator.run!
    content = File.read(File.join(config.abs_manifest_dir, "ux_admin.js"))
    expect(content).to include("AUTO-GENERATED")
  end

  it "no spurious manifests are created for intermediate namespace dirs" do
    generator.run!
    reports_path = File.join(config.abs_manifest_dir, "ux_admin_reports.js")
    summary_path = File.join(config.abs_manifest_dir, "ux_admin_reports_summary.js")
    expect(File.exist?(reports_path)).to be false
    expect(File.exist?(summary_path)).to be false
  end
end
