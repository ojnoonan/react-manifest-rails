require "benchmark"
require "spec_helper"
require "support/stress_fixture_builder"

RSpec.describe "Stress: flat scale (100+ controllers)", :stress do
  around(:each) do |example|
    Dir.mktmpdir("react_manifest_stress") do |tmpdir|
      Rails.root = tmpdir
      ReactManifest.reset!
      StressFixtureBuilder.build_flat(tmpdir, controller_count: 100, files_per_controller: 3)
      StressFixtureBuilder.configure_for(tmpdir)
      example.run
    end
  end

  let(:config)    { ReactManifest.configuration }
  let(:generator) { ReactManifest::Generator.new(config) }

  it "generates one manifest per controller" do
    generator.run!
    manifests = Dir.glob(File.join(config.abs_manifest_dir, "ux_ctrl_*.js"))
    expect(manifests.length).to eq(100)
  end

  it "ux_shared.js is generated" do
    generator.run!
    expect(File.exist?(File.join(config.abs_manifest_dir, "ux_shared.js"))).to be true
  end

  it "each controller manifest requires only its own source files (spot-check 5)" do
    generator.run!
    (1..5).each do |i|
      path    = File.join(config.abs_manifest_dir, "ux_ctrl_#{i}.js")
      content = File.read(path)
      expect(content).to include("//= require ux/app/ctrl_#{i}/ctrl_#{i}_0"),
                         "ux_ctrl_#{i}.js is missing its own source requires"
    end
  end

  it "all generated manifests carry the AUTO-GENERATED header" do
    generator.run!
    Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js")).each do |path|
      expect(File.read(path)).to include("AUTO-GENERATED"),
                                 "#{File.basename(path)} is missing AUTO-GENERATED header"
    end
  end

  it "completes within 10 seconds" do
    elapsed = Benchmark.realtime { generator.run! }
    expect(elapsed).to be < 10
  end
end
