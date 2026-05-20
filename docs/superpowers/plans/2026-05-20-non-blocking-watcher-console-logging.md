# Non-blocking Watcher & Console Logging Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three related development-mode bugs: watcher regeneration blocks the listen thread, ReactManifest stdout output interferes with Rails console input, and duplicate/spurious log lines pollute the console.

**Architecture:** Two files change. `watcher.rb` gets a mutex+pending-flag coalescing loop so the listen callback returns immediately and regeneration runs in a background thread; `regenerate!` inspects results and stays silent on no-op runs. `logging.rb` gains a `rails_console?` guard so `$stdout.puts` is skipped when `Rails::Console` is defined, eliminating both the duplicate-line and mid-prompt-write problems in one check.

**Tech Stack:** Ruby stdlib `Mutex`, `Thread`, `Queue`; Minitest + Mocha

---

## File map

| File | Change |
|---|---|
| `lib/react_manifest/watcher.rb` | Add `schedule_regeneration`, `regen_loop`; mutex+pending state; update `handle_file_changes`, `stop`, `regenerate!` |
| `lib/react_manifest/logging.rb` | Add private `rails_console?` and `stdout_logging_needed?`; update all three log methods |
| `test/react_manifest/watcher_test.rb` | Add teardown; update existing tests to join thread; add 3 new tests |
| `test/react_manifest/logging_test.rb` | Add 3 new console-detection tests |

---

## Task 1: Silence log output on no-op regeneration

**Files:**
- Modify: `lib/react_manifest/watcher.rb`
- Test: `test/react_manifest/watcher_test.rb`

- [ ] **Step 1: Write two failing tests**

Add to `WatcherTest` in `test/react_manifest/watcher_test.rb`:

```ruby
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
```

- [ ] **Step 2: Verify tests fail**

```bash
bundle exec ruby -Itest test/react_manifest/watcher_test.rb
```

Expected: both new tests fail — `regenerate!` currently calls `log_info "Manifests regenerated"` unconditionally.

- [ ] **Step 3: Update `regenerate!` in `watcher.rb`**

Replace the current `regenerate!` private method (lines 63–69):

```ruby
def regenerate!(config)
  Generator.new(config).run!
  log_info "Manifests regenerated"
rescue StandardError => e
  log_warn "Error during regeneration: #{e.message}"
  log_debug e.backtrace.first(5).join("\n") if config.verbose?
end
```

with:

```ruby
def regenerate!(config)
  results = Generator.new(config).run!
  written = results.count { |r| r[:status] == :written }
  log_info "#{written} manifest(s) written" if written.positive?
rescue StandardError => e
  log_warn "Error during regeneration: #{e.message}"
  log_debug e.backtrace.first(5).join("\n") if config.verbose?
end
```

- [ ] **Step 4: Verify tests pass**

```bash
bundle exec ruby -Itest test/react_manifest/watcher_test.rb
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/watcher.rb test/react_manifest/watcher_test.rb
git commit -m "fix: silence watcher log output when no manifests were written"
```

---

## Task 2: Add `rails_console?` guard to Logging

**Files:**
- Modify: `lib/react_manifest/logging.rb`
- Test: `test/react_manifest/logging_test.rb`

- [ ] **Step 1: Write three failing tests**

Add to `LoggingTest` in `test/react_manifest/logging_test.rb`:

```ruby
def test_log_info_does_not_write_to_stdout_in_rails_console_mode
  ReactManifest.configure { |c| c.stdout_logging = true }
  FakeRails::Console = Class.new
  $stdout.expects(:puts).never
  @host.log_info("started")
ensure
  FakeRails.send(:remove_const, :Console) if FakeRails.const_defined?(:Console)
end

def test_log_debug_does_not_write_to_stdout_in_rails_console_mode
  ReactManifest.configure { |c| c.stdout_logging = true }
  FakeRails::Console = Class.new
  $stdout.expects(:puts).never
  @host.log_debug("verbose detail")
ensure
  FakeRails.send(:remove_const, :Console) if FakeRails.const_defined?(:Console)
end

def test_log_warn_does_not_write_to_stdout_in_rails_console_mode
  ReactManifest.configure { |c| c.stdout_logging = true }
  FakeRails::Console = Class.new
  $stdout.expects(:puts).never
  @host.log_warn("uh oh")
ensure
  FakeRails.send(:remove_const, :Console) if FakeRails.const_defined?(:Console)
end
```

- [ ] **Step 2: Verify tests fail**

```bash
bundle exec ruby -Itest test/react_manifest/logging_test.rb
```

Expected: all three new tests fail — `$stdout.puts` is currently called unconditionally when `stdout_logging?` is true.

- [ ] **Step 3: Replace `logging.rb` with the guarded version**

Full file replacement for `lib/react_manifest/logging.rb`:

```ruby
module ReactManifest
  module Logging
    def log_debug(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.debug(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    def log_info(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.info(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    def log_warn(message)
      full = "[ReactManifest] #{message}"
      Rails.logger.warn(full)
      $stdout.puts(full) if stdout_logging_needed?
    end

    private

    def stdout_logging_needed?
      ReactManifest.configuration.stdout_logging? && !rails_console?
    end

    def rails_console?
      defined?(Rails::Console)
    end
  end
end
```

- [ ] **Step 4: Verify tests pass**

```bash
bundle exec ruby -Itest test/react_manifest/logging_test.rb
```

Expected: all 10 tests pass (7 existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/logging.rb test/react_manifest/logging_test.rb
git commit -m "fix: suppress stdout logging in Rails console to prevent duplicate output and prompt interference"
```

---

## Task 3: Non-blocking watcher with mutex coalescing

**Files:**
- Modify: `lib/react_manifest/watcher.rb`
- Test: `test/react_manifest/watcher_test.rb`

The listen gem fires its callback on an internal thread. `handle_file_changes` currently calls `regenerate!` directly on that thread, blocking it for the duration of a scan. The fix: `handle_file_changes` calls `schedule_regeneration` which spawns a background thread and returns immediately. A `Mutex` + boolean flag ensure only one generator runs at a time; if changes arrive mid-run, exactly one follow-up run is guaranteed.

- [ ] **Step 1: Add teardown and fix existing test stubs in `watcher_test.rb`**

The existing tests call `handle_file_changes` which (after this task) will spawn a background thread. Without joining it, Mocha expectations are checked before the thread runs, causing flaky failures. Also, stubs that currently return `nil` from `run!` must return an array (otherwise `regenerate!`'s `results.count` raises `NoMethodError`).

Replace the full `WatcherTest` class in `test/react_manifest/watcher_test.rb` with:

```ruby
require "test_helper"

class WatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def teardown
    super
    # Reset per-class watcher thread state between tests
    ReactManifest::Watcher.instance_variable_set(:@regen_thread, nil)
    ReactManifest::Watcher.instance_variable_set(:@regen_pending, false)
    ReactManifest::Watcher.instance_variable_set(:@regen_mutex, nil)
  end

  def join_regen_thread(timeout: 2)
    ReactManifest::Watcher.instance_variable_get(:@regen_thread)&.join(timeout)
  end

  def test_routes_log_messages_through_rails_logger_info
    Rails.logger.expects(:info).with("[ReactManifest] test message")
    ReactManifest::Watcher.send(:log_info, "test message")
  end

  def test_invalidates_each_modified_file_in_scanner_cache
    modified_file = "/path/to/ux/components/button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!).returns([{ status: :unchanged }])
    ReactManifest::Scanner.expects(:invalidate).with(modified_file)
    ReactManifest::Watcher.send(:handle_file_changes, [modified_file], [], [], @config)
    join_regen_thread
  end

  def test_invalidates_each_added_file_in_scanner_cache
    added_file = "/path/to/ux/components/new_button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!).returns([{ status: :unchanged }])
    ReactManifest::Scanner.expects(:invalidate).with(added_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [added_file], [], @config)
    join_regen_thread
  end

  def test_invalidates_each_removed_file_in_scanner_cache
    removed_file = "/path/to/ux/components/old_button.jsx"
    ReactManifest::Generator.any_instance.stubs(:run!).returns([{ status: :unchanged }])
    ReactManifest::Scanner.expects(:invalidate).with(removed_file)
    ReactManifest::Watcher.send(:handle_file_changes, [], [], [removed_file], @config)
    join_regen_thread
  end

  def test_triggers_manifest_regeneration_after_invalidation
    generator = mock("generator")
    ReactManifest::Generator.expects(:new).with(@config).returns(generator)
    generator.expects(:run!).returns([{ status: :unchanged }])
    ReactManifest::Watcher.send(:handle_file_changes, ["/any/file.js"], [], [], @config)
    join_regen_thread
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
```

- [ ] **Step 2: Write the coalescing test**

Add this test to `WatcherTest` (inside the class, after the last test):

```ruby
def test_coalesces_changes_arriving_during_regeneration
  call_count = 0
  started = Queue.new  # regen thread signals when run! has been entered
  proceed = Queue.new  # test signals when run! may return

  generator = Object.new
  generator.define_singleton_method(:run!) do
    started.push(true)
    proceed.pop
    call_count += 1
    [{ status: :unchanged }]
  end
  ReactManifest::Generator.stubs(:new).returns(generator)

  # First change — spawns background thread, which blocks inside run!
  ReactManifest::Watcher.send(:handle_file_changes, ["/f1.js"], [], [], @config)
  started.pop  # wait until regeneration has actually started

  # Second change arrives while first is still running — must set pending flag
  ReactManifest::Watcher.send(:handle_file_changes, ["/f2.js"], [], [], @config)

  # Unblock first run; coalescing loop detects pending and starts a second run
  proceed.push(true)
  started.pop  # wait for the coalesced second run to start
  proceed.push(true)  # unblock it

  join_regen_thread
  assert_equal 2, call_count, "Expected 2 regenerations: initial + one coalesced follow-up"
end
```

- [ ] **Step 3: Verify the coalescing test fails (and existing tests still pass)**

```bash
bundle exec ruby -Itest test/react_manifest/watcher_test.rb
```

Expected: `test_coalesces_changes_arriving_during_regeneration` fails (hangs or errors because `schedule_regeneration` doesn't exist yet). The other tests should still pass because `handle_file_changes` hasn't changed yet.

Actually, since `schedule_regeneration` doesn't exist the test will raise `NoMethodError` on the second `handle_file_changes` call once we update the method — for now the test just runs but hangs. Stop it with Ctrl-C after confirming. Move on to implementation.

- [ ] **Step 4: Replace `watcher.rb` with the non-blocking implementation**

Full file replacement for `lib/react_manifest/watcher.rb`:

```ruby
module ReactManifest
  # Watches the ux/ directory tree for file changes and triggers
  # manifest regeneration automatically.
  #
  # Uses the `listen` gem (soft dependency — degrades gracefully if not available).
  # Auto-started in development via the Railtie initializer.
  #
  # Watches ux_root recursively so newly added controller directories are
  # picked up without a server restart.
  module Watcher
    DEBOUNCE_SECONDS = 0.3

    class << self
      include ReactManifest::Logging

      def start(config = ReactManifest.configuration)
        begin
          require "listen"
        rescue LoadError
          log_warn "listen gem not available — file watching disabled. " \
                   "Add `gem 'listen'` to the development group in your Gemfile."
          return
        end

        root = config.abs_ux_root

        unless Dir.exist?(root)
          log_warn "ux_root does not exist (#{root}) — file watching disabled until directory is created."
          return
        end

        log_info "Watching #{root.sub("#{Rails.root}/", '')} for changes..."

        @listener = Listen.to(
          root,
          only: config.extensions_pattern,
          latency: DEBOUNCE_SECONDS
        ) do |modified, added, removed|
          changed = (modified + added + removed).map { |f| File.basename(f) }
          log_info "File change detected: #{changed.join(', ')}"
          handle_file_changes(modified, added, removed, config)
        end

        @listener.start
      end

      def stop
        @listener&.stop
        @listener = nil
        @regen_thread&.join(5)
        @regen_thread = nil
      end

      def running?
        !@listener.nil?
      end

      private

      def handle_file_changes(modified, added, removed, config)
        (modified + added + removed).each { |f| Scanner.invalidate(f) }
        schedule_regeneration(config)
      end

      # Dispatches regeneration to a background thread and returns immediately,
      # keeping the listen callback thread free for new events.
      #
      # Only one Generator runs at a time (mutex). If a second change arrives
      # while regeneration is in progress, the pending flag is set and the
      # running thread loops for exactly one more pass before exiting.
      def schedule_regeneration(config)
        @regen_mutex ||= Mutex.new
        @regen_mutex.synchronize do
          @regen_pending = true
          return if @regen_thread&.alive?
          @regen_thread = Thread.new { regen_loop(config) }
        end
      end

      def regen_loop(config)
        loop do
          @regen_mutex.synchronize { @regen_pending = false }
          regenerate!(config)
          @regen_mutex.synchronize { break unless @regen_pending }
        end
      end

      def regenerate!(config)
        results = Generator.new(config).run!
        written = results.count { |r| r[:status] == :written }
        log_info "#{written} manifest(s) written" if written.positive?
      rescue StandardError => e
        log_warn "Error during regeneration: #{e.message}"
        log_debug e.backtrace.first(5).join("\n") if config.verbose?
      end
    end
  end
end
```

- [ ] **Step 5: Verify all watcher tests pass**

```bash
bundle exec ruby -Itest test/react_manifest/watcher_test.rb
```

Expected: all tests pass including `test_coalesces_changes_arriving_during_regeneration`.

- [ ] **Step 6: Run the full test suite**

```bash
bundle exec ruby -Itest test/**/*_test.rb
```

Expected: all tests pass. If any integration tests fail because they stub `run!` without returning an array, update those stubs to `.returns([{ status: :unchanged }])`.

- [ ] **Step 7: Commit**

```bash
git add lib/react_manifest/watcher.rb test/react_manifest/watcher_test.rb
git commit -m "fix: make watcher regeneration non-blocking with mutex coalescing"
```

---

## Verification

After all three tasks are committed, run the full suite one final time:

```bash
bundle exec ruby -Itest test/**/*_test.rb
```

Expected: green across all test files. No failures, no hangs.
