require "spec_helper"

# The Railtie itself cannot be unit-tested without a real Rails boot, but it
# is responsible for calling Generator.run! on every development boot.
# These specs verify the Generator behavior that the Railtie must always
# exercise — specifically that re-running the generator after new shared files
# are added (e.g. via a git merge) produces updated manifests.
RSpec.describe "Railtie boot-time generation behaviour" do
  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  def ux_root
    config.abs_ux_root
  end

  def output_dir
    config.abs_manifest_dir
  end

  def shared_content
    File.read(File.join(output_dir, "ux_shared.js"), encoding: "utf-8")
  end

  def run_generator
    ReactManifest::Generator.new(config).run!
  end

  # Simulates what the Railtie does on every development boot.
  # A new shared file added between boots (e.g. via git merge) must appear
  # in ux_shared.js after the next boot's generator run.
  describe "picking up new shared files on re-run" do
    it "includes a file added to hooks/ between two generator runs" do
      run_generator

      new_hook = File.join(ux_root, "hooks", "index_table_hooks.js")
      File.write(new_hook, "export function useIndexTable() {}\n")

      run_generator

      expect(shared_content).to include("ux/hooks/index_table_hooks")
    end

    it "includes a file added to components/ between two generator runs" do
      run_generator

      new_component = File.join(ux_root, "components", "data_grid.js")
      File.write(new_component, "export default function DataGrid() {}\n")

      run_generator

      expect(shared_content).to include("ux/components/data_grid")
    end
  end

  describe "idempotency between boots" do
    it "returns :unchanged for all manifests when nothing changes" do
      run_generator

      results = run_generator

      statuses = results.map { |r| r[:status] }
      expect(statuses).to all(eq(:unchanged))
    end

    it "does not modify manifest mtime when nothing changes" do
      run_generator

      mtimes_before = Dir.glob(File.join(output_dir, "ux_*.js")).to_h { |f| [f, File.mtime(f)] }
      sleep 0.02
      run_generator
      mtimes_after = Dir.glob(File.join(output_dir, "ux_*.js")).to_h { |f| [f, File.mtime(f)] }

      expect(mtimes_after).to eq(mtimes_before)
    end
  end
end
