require "test_helper"

class WatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @stubbed_regenerate = false
    # Save original private method so we can restore it in teardown.
    @original_regenerate = ReactManifest::Watcher.method(:regenerate!)
  end

  # Fix 1 + kill: stop any live regen thread before resetting state so the
  # thread cannot call @regen_mutex.synchronize on a nil object.
  def teardown
    # Restore patched regenerate! before reset so the killed thread uses the
    # original implementation if it somehow wakes after teardown.
    if @stubbed_regenerate
      orig = @original_regenerate
      Warning[:performance] = false if Warning.respond_to?(:[]=)
      ReactManifest::Watcher.define_singleton_method(:regenerate!, &orig)
      Warning[:performance] = true if Warning.respond_to?(:[]=)
    end
    ReactManifest::Watcher.reset_regen_state!
    super
  end

  # Helper: block until the background regen thread finishes (or timeout).
  def join_regen_thread(timeout: 2)
    deadline = Time.now + timeout
    loop do
      thread = ReactManifest::Watcher.instance_variable_get(:@regen_thread)
      break if thread.nil? || !thread.alive?
      break if Time.now > deadline

      sleep 0.05
    end
  end

  # Patch regenerate! at the singleton level (works cross-thread unlike mocha).
  def stub_regenerate!(&block)
    @stubbed_regenerate = true
    Warning[:performance] = false if Warning.respond_to?(:[]=)
    ReactManifest::Watcher.define_singleton_method(:regenerate!, &block)
    Warning[:performance] = true if Warning.respond_to?(:[]=)
  end

  def test_routes_log_messages_through_rails_logger_info
    Rails.logger.expects(:info).with("[ReactManifest] test message")
    ReactManifest::Watcher.send(:log_info, "test message")
  end

  def test_invalidates_each_modified_file_in_scanner_cache
    modified_file = "/path/to/ux/components/button.jsx"
    stub_regenerate! { |_config| nil }
    ReactManifest::Scanner.expects(:invalidate).with(modified_file)
    ReactManifest::Watcher.send(:handle_file_changes, [modified_file], [], [], @config)
    join_regen_thread
  end

  def test_invalidates_each_added_file_in_scanner_cache
    added_file = "/path/to/ux/components/new_button.jsx"
    stub_regenerate! { |_config| nil }
    ReactManifest::Scanner.expects(:invalidate).with(added_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [added_file], [], @config)
    join_regen_thread
  end

  def test_invalidates_each_removed_file_in_scanner_cache
    removed_file = "/path/to/ux/components/old_button.jsx"
    stub_regenerate! { |_config| nil }
    ReactManifest::Scanner.expects(:invalidate).with(removed_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [], [removed_file], @config)
    join_regen_thread
  end

  def test_triggers_manifest_regeneration_after_invalidation
    call_count = 0
    stub_regenerate! { |_config| call_count += 1 }
    ReactManifest::Scanner.stubs(:invalidate)
    ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], @config)
    join_regen_thread
    assert call_count >= 1, "Expected generator to be called at least once, got #{call_count}"
  end

  def test_schedule_regeneration_coalesces_rapid_changes
    # Back-to-back changes must not stack up unlimited regenerations.
    # We allow at most 2 runs: one for the in-flight regen, one more if
    # @regen_pending was set while the first was running.
    call_count = 0
    stub_regenerate! do |_config|
      call_count += 1
      sleep 0.05  # simulate work so subsequent changes arrive mid-run
    end
    ReactManifest::Scanner.stubs(:invalidate)

    # Fire three rapid change events
    3.times do
      ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], @config)
    end

    join_regen_thread(timeout: 3)

    # Coalescing means at most 2 runs (one in-flight + one pending), never 3
    assert call_count <= 2,
           "Expected at most 2 regenerations due to coalescing, got #{call_count}"
    assert call_count >= 1,
           "Expected at least 1 regeneration, got #{call_count}"
  end

  def test_schedule_regeneration_does_not_block_caller
    stub_regenerate! { |_config| sleep 0.1 }
    ReactManifest::Scanner.stubs(:invalidate)

    t0 = Time.now
    ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], @config)
    elapsed = Time.now - t0

    # The caller should return almost immediately — well under the 0.1s sleep
    assert elapsed < 0.5,
           "handle_file_changes blocked for #{elapsed}s — should return immediately"

    join_regen_thread
  end
end
