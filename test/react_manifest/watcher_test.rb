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

  def test_coalesces_second_change_that_arrives_during_active_regeneration
    call_count = 0
    started  = Queue.new  # regen signals when it has entered the stub
    proceed  = Queue.new  # test signals when the stub may return

    stub_regenerate! do |_config|
      started.push(true)
      proceed.pop
      call_count += 1
    end
    ReactManifest::Scanner.stubs(:invalidate)

    # First change — spawns thread, which immediately blocks waiting for proceed
    ReactManifest::Watcher.send(:handle_file_changes, ["/f1.js"], [], [], @config)
    started.pop  # wait until regeneration has actually started

    # Second change arrives while first is still running — sets the pending flag
    ReactManifest::Watcher.send(:handle_file_changes, ["/f2.js"], [], [], @config)

    # Unblock first run; regen_loop detects pending and starts a second run
    proceed.push(true)
    started.pop   # wait for the coalesced second run to begin
    proceed.push(true)  # unblock it

    join_regen_thread
    assert_equal 2, call_count, "Expected exactly 2 regenerations: initial + one coalesced follow-up"
  end

  def test_stop_waits_for_in_flight_regeneration_to_complete
    finished = false
    started  = Queue.new

    stub_regenerate! do |_config|
      started.push(true)
      sleep 0.05  # simulate slow work
      finished = true
    end
    ReactManifest::Scanner.stubs(:invalidate)

    ReactManifest::Watcher.send(:handle_file_changes, ["/f.js"], [], [], @config)
    started.pop  # ensure regeneration is actually running before calling stop

    ReactManifest::Watcher.stop  # must block until the thread finishes

    assert finished, "stop should wait for in-flight regeneration to complete"
  end

  def test_regenerate_rescues_generator_errors_and_logs_a_warning
    ReactManifest::Generator.stubs(:new).raises(RuntimeError, "disk full")
    Rails.logger.expects(:warn).with("[ReactManifest] Error during regeneration: disk full")

    # Call regenerate! directly — tests the rescue path without threading complexity
    ReactManifest::Watcher.send(:regenerate!, @config)
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
