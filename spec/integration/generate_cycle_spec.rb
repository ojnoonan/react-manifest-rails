require "spec_helper"

RSpec.describe "Integration: full generate cycle" do
  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  let(:config)    { ReactManifest.configuration }
  let(:generator) { ReactManifest::Generator.new(config) }

  before { generator.run! }

  def manifest(name)
    File.read(File.join(config.abs_manifest_dir, name))
  end

  it "writes ux_shared.js with shared component requires" do
    content = manifest("ux_shared.js")
    expect(content).to include("//= require ux/components/buttons/primary_button")
    expect(content).to include("//= require ux/hooks/use_fetch")
    expect(content).to include("//= require ux/lib/api_helpers")
  end

  it "writes a per-controller manifest for each app subdirectory" do
    %w[ux_users.js ux_notifications.js ux_orders.js ux_products.js].each do |name|
      expect(File.exist?(File.join(config.abs_manifest_dir, name))).to be true
    end
  end

  it "controller manifest does not inline shared source files" do
    content = manifest("ux_notifications.js")
    expect(content).not_to include("ux/components/")
    expect(content).not_to include("ux/hooks/")
    expect(content).not_to include("ux/lib/")
  end

  it "controller manifest requires its own controller files" do
    content = manifest("ux_notifications.js")
    expect(content).to include("//= require ux/app/notifications/notifications_index")
    expect(content).to include("//= require ux/app/notifications/notifications_show")
  end

  it "all generated manifests carry the AUTO-GENERATED header" do
    Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js")).each do |path|
      expect(File.read(path)).to include("AUTO-GENERATED"), "#{File.basename(path)} is missing AUTO-GENERATED header"
    end
  end
end
