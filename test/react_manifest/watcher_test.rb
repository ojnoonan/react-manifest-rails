require "test_helper"

class WatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def test_routes_log_messages_through_rails_logger_info
    Rails.logger.expects(:info).with("[ReactManifest] test message")
    ReactManifest::Watcher.send(:log_info, "test message")
  end

  def test_invalidates_each_modified_file_in_scanner_cache
    modified_file = "/path/to/ux/components/button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!)
    ReactManifest::Scanner.expects(:invalidate).with(modified_file)
    ReactManifest::Watcher.send(:handle_file_changes, [modified_file], [], [], @config)
  end

  def test_invalidates_each_added_file_in_scanner_cache
    added_file = "/path/to/ux/components/new_button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!)
    ReactManifest::Scanner.expects(:invalidate).with(added_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [added_file], [], @config)
  end

  def test_invalidates_each_removed_file_in_scanner_cache
    removed_file = "/path/to/ux/components/old_button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!)
    ReactManifest::Scanner.expects(:invalidate).with(removed_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [], [removed_file], @config)
  end

  def test_triggers_manifest_regeneration_after_invalidation
    generator = mock("generator")
    ReactManifest::Generator.expects(:new).with(@config).returns(generator)
    generator.expects(:run!)
    ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], @config)
  end

  def test_does_not_log_when_all_manifests_are_unchanged
    generator = mock("generator")
    ReactManifest::Generator.stubs(:new).returns(generator)
    generator.stubs(:run!).returns([{ status: :unchanged }, { status: :unchanged }])
    Rails.logger.expects(:info).never
    ReactManifest::Watcher.send(:regenerate!, @config)
  end

  def test_logs_written_count_when_manifests_are_written
    generator = mock("generator")
    ReactManifest::Generator.stubs(:new).returns(generator)
    generator.stubs(:run!).returns([{ status: :written }, { status: :unchanged }])
    Rails.logger.expects(:info).with("[ReactManifest] 1 manifest(s) written")
    ReactManifest::Watcher.send(:regenerate!, @config)
  end
end
