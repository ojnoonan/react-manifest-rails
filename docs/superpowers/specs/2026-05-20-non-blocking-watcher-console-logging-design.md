# Non-blocking watcher regeneration + console logging fixes

**Date:** 2026-05-20  
**Status:** Approved

## Problem

Three related issues reported in development:

1. **Watcher blocks during file changes.** The listen gem fires its callback on an internal thread. Because `Generator.run!` is called synchronously inside that callback, the thread is occupied for the full duration of a scan. On large projects, subsequent file-change events queue up and regeneration lags noticeably.

2. **ReactManifest output lands in the Rails console input area.** The listen background thread writes to `$stdout` via the Logging mixin while IRB's Reline is managing the input prompt. Concurrent `$stdout` writes from background threads interleave with the prompt cursor, making output appear inside the input line.

3. **Duplicate log lines in Rails console.** `Rails.logger` in console mode is already routed to `$stdout`. The Logging mixin additionally calls `$stdout.puts` for the same message, so every line appears twice.

## Root causes

| Issue | Root cause |
|---|---|
| Blocking | `Watcher#regenerate!` called directly on the listen callback thread |
| Console interference | `$stdout.puts` called from background thread; conflicts with Reline cursor |
| Duplicates | `Rails.logger` + `$stdout.puts` both write to `$stdout` in console mode |

## Design

### 1. Non-blocking watcher regeneration (`watcher.rb`)

Replace the direct `regenerate!` call in `handle_file_changes` with a `schedule_regeneration` helper that offloads work to a background thread. The listen callback returns immediately.

**Invariants:**
- Only one `Generator` instance runs at a time — no concurrent manifest writes.
- If new changes arrive while a regeneration is in progress, exactly one follow-up run is guaranteed.
- No change events are silently dropped.

**Mechanism — mutex + pending flag + coalescing loop:**

```
Mutex guards: @regen_pending (bool), @regen_thread (Thread|nil)

schedule_regeneration(config):
  mutex.synchronize:
    @regen_pending = true
    return if @regen_thread&.alive?
    @regen_thread = Thread.new { regen_loop(config) }

regen_loop(config):
  loop:
    mutex.synchronize { @regen_pending = false }
    regenerate!(config)            # outside mutex — changes can arrive freely
    mutex.synchronize { break unless @regen_pending }
```

The spawned thread loops until no pending flag is set, then exits. `schedule_regeneration` only spawns a new thread when the previous one has exited.

**Shutdown:** `Watcher.stop` gains `@regen_thread&.join(5)` (5-second timeout) so an in-flight regeneration is allowed to finish before the process exits cleanly.

**Environment scope:** Watcher only starts in `Rails.env.development?` (Railtie guard unchanged). This change only affects the threading model inside an already-running watcher.

### 2. Console logging guard (`logging.rb`)

Add a private `rails_console?` helper to the Logging mixin. When true, skip the `$stdout.puts` call — rely on `Rails.logger` only.

```ruby
def rails_console?
  defined?(Rails::Console)
end
```

`Rails::Console` is set by Rails exclusively when the `rails console` command is running. It is **not** set in:
- Rails server
- Rake tasks (`assets:precompile`, `react_manifest:generate`)
- Test suite
- CI environments

This means:
- **Server mode:** `$stdout.puts` still fires (if `stdout_logging?` is true), behaviour unchanged.
- **Console mode:** only `Rails.logger` fires → one line, no mid-prompt writes.
- **Test/CI:** unaffected.

Updated guard in each log method:

```ruby
$stdout.puts(full) if ReactManifest.configuration.stdout_logging? && !rails_console?
```

## Files changed

| File | Change |
|---|---|
| `lib/react_manifest/watcher.rb` | Add `schedule_regeneration`, `regen_loop`; mutex + pending flag; update `handle_file_changes` and `stop` |
| `lib/react_manifest/logging.rb` | Add `rails_console?` private helper; guard `$stdout.puts` calls |

## Testing

- Existing watcher specs should still pass with the threading change (generation result is the same).
- Add a spec for `Watcher` that verifies: when `handle_file_changes` is called twice in rapid succession while regeneration is slow, exactly two generations occur (first + one coalesced follow-up), not three or more.
- Add a spec for `Logging` that verifies `$stdout` is not written when `Rails::Console` is defined.
