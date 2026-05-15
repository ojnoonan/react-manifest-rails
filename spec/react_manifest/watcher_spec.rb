require "spec_helper"

RSpec.describe ReactManifest::Watcher do
  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  describe "logging" do
    it "routes Watcher log messages through Rails.logger.info" do
      allow(Rails.logger).to receive(:info)
      ReactManifest::Watcher.send(:log_info, "test message")
      expect(Rails.logger).to have_received(:info).with("[ReactManifest] test message")
    end
  end

  describe "file-change cache invalidation" do
    let(:config) { ReactManifest.configuration }

    before do
      allow_any_instance_of(ReactManifest::Generator).to receive(:run!)
    end

    it "invalidates each modified file in the Scanner cache" do
      modified_file = "/path/to/ux/components/button.jsx"
      expect(ReactManifest::Scanner).to receive(:invalidate).with(modified_file)

      ReactManifest::Watcher.send(:handle_file_changes, [modified_file], [], [], config)
    end

    it "invalidates each added file in the Scanner cache" do
      added_file = "/path/to/ux/components/new_button.jsx"
      expect(ReactManifest::Scanner).to receive(:invalidate).with(added_file)

      ReactManifest::Watcher.send(:handle_file_changes, [], [added_file], [], config)
    end

    it "invalidates each removed file in the Scanner cache" do
      removed_file = "/path/to/ux/components/old_button.jsx"
      expect(ReactManifest::Scanner).to receive(:invalidate).with(removed_file)

      ReactManifest::Watcher.send(:handle_file_changes, [], [], [removed_file], config)
    end

    it "triggers manifest regeneration after invalidation" do
      generator = instance_double(ReactManifest::Generator)
      allow(ReactManifest::Generator).to receive(:new).with(config).and_return(generator)
      expect(generator).to receive(:run!)

      ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], config)
    end
  end
end
