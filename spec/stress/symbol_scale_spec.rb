require "benchmark"
require "spec_helper"
require "support/stress_fixture_builder"

RSpec.describe "Stress: symbol scale (500+ shared symbols)", :stress do
  around(:each) do |example|
    Dir.mktmpdir("react_manifest_stress") do |tmpdir|
      Rails.root = tmpdir
      ReactManifest.reset!
      StressFixtureBuilder.build_symbol_scale(tmpdir, shared_files: 50, symbols_per_file: 10)
      StressFixtureBuilder.configure_for(tmpdir)
      example.run
    end
  end

  let(:config)    { ReactManifest.configuration }
  let(:generator) { ReactManifest::Generator.new(config) }

  it "ux_shared.js requires all 50 shared component files" do
    generator.run!
    content = File.read(File.join(config.abs_manifest_dir, "ux_shared.js"))
    50.times do |fi|
      expect(content).to include("//= require ux/components/group_#{fi}"),
                         "ux_shared.js is missing group_#{fi}"
    end
  end

  it "ux_shared.js carries the AUTO-GENERATED header" do
    generator.run!
    content = File.read(File.join(config.abs_manifest_dir, "ux_shared.js"))
    expect(content).to include("AUTO-GENERATED")
  end

  it "completes within 10 seconds" do
    elapsed = Benchmark.realtime { generator.run! }
    expect(elapsed).to be < 10
  end
end
