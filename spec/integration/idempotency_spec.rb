require "spec_helper"

RSpec.describe "Integration: idempotent generation" do
  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  let(:config)    { ReactManifest.configuration }
  let(:generator) { ReactManifest::Generator.new(config) }

  it "second run reports all manifests as unchanged" do
    generator.run!
    results = generator.run!
    unchanged = results.select { |r| r[:status] == :unchanged }
    expect(unchanged.length).to eq(results.length)
  end

  it "second run does not rewrite any files (mtimes are stable)" do
    generator.run!
    mtimes_before = Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js"))
                       .to_h { |f| [f, File.mtime(f)] }
    sleep 0.01
    generator.run!
    mtimes_after = Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js"))
                      .to_h { |f| [f, File.mtime(f)] }

    mtimes_before.each do |path, mtime|
      expect(mtimes_after[path]).to eq(mtime), "#{File.basename(path)} was rewritten on second run"
    end
  end

  it "second run produces identical file content" do
    generator.run!
    contents_before = Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js"))
                         .to_h { |f| [File.basename(f), File.read(f)] }
    generator.run!
    contents_after = Dir.glob(File.join(config.abs_manifest_dir, "ux_*.js"))
                        .to_h { |f| [File.basename(f), File.read(f)] }

    expect(contents_after).to eq(contents_before)
  end
end
