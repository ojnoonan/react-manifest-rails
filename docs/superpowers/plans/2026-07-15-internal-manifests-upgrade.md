# Internal (Gitignored) Manifests + Zero-Touch Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Treat generated `ux_manifests/*.js` as gitignored build artifacts, and make an existing app upgrade with zero manual steps — on dev boot the gem regenerates manifests (already happens) and ensures the `.gitignore` entry + `.keep` exist, idempotently and best-effort.

**Architecture:** A new `GitignorePatcher` (mirroring `SprocketsManifestPatcher`) idempotently appends `output_dir/ux_manifests/*.js` to `.gitignore` and ensures a committed `.keep`. A testable module method `ReactManifest.reconcile_gitignore!` wraps it with the `manage_gitignore` guard and an "untrack" hint; the Railtie's dev-only boot step and `react_manifest:setup` both call it. No asset-pipeline changes — `link_tree` and the generation path are untouched. Production never mutates the tree at boot.

**Tech Stack:** Ruby, Minitest, the `with_temp_rails_root`/`ReactManifestTest` fixture harness, `ReactManifest::Logging`.

**Spec:** `docs/superpowers/specs/2026-07-15-hands-free-bundles-design.md` (Feature 2 §4, upgrade §4.2; tests §5.12–5.13).

**Depends on:** none (independent of the auto-promotion plan; can ship before or after it).

---

### Task 1: Add `config.manage_gitignore` flag

**Files:**
- Modify: `lib/react_manifest/configuration.rb` (accessor + initialize + predicate)
- Test: `test/react_manifest/configuration_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
def test_manage_gitignore_defaults_to_true
  assert_equal true, ReactManifest::Configuration.new.manage_gitignore?
end

def test_manage_gitignore_can_be_disabled
  config = ReactManifest::Configuration.new
  config.manage_gitignore = false
  assert_equal false, config.manage_gitignore?
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/configuration_test.rb`
Expected: FAIL — `undefined method 'manage_gitignore?'`

- [ ] **Step 3: Write minimal implementation**

Add the accessor (near `:manifest_subdir`):

```ruby
    # When true (default), the gem ensures the generated manifest dir is gitignored
    # (adds the entry on dev boot if missing). Set false to manage .gitignore yourself.
    attr_accessor :manage_gitignore
```

In `initialize`, after `@manifest_subdir = "ux_manifests"`:

```ruby
      @manage_gitignore  = true
```

Predicate after `stdout_logging?`:

```ruby
    def manage_gitignore?
      !!@manage_gitignore
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/configuration_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/configuration.rb test/react_manifest/configuration_test.rb
git commit -m "feat: add config.manage_gitignore flag (default true)"
```

---

### Task 2: `GitignorePatcher` — idempotent `.gitignore` entry + `.keep`

**Files:**
- Create: `lib/react_manifest/gitignore_patcher.rb`
- Modify: `lib/react_manifest.rb` (add `require`)
- Test: `test/react_manifest/gitignore_patcher_test.rb` (new)

- [ ] **Step 1: Write the failing test**

Create `test/react_manifest/gitignore_patcher_test.rb`:

```ruby
require "test_helper"

class GitignorePatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @patcher = ReactManifest::GitignorePatcher.new(@config)
  end

  def gitignore_path
    Rails.root.join(".gitignore").to_s
  end

  def test_pattern_is_derived_from_config
    assert_equal "app/assets/javascripts/ux_manifests/*.js", @patcher.pattern
  end

  def test_appends_entry_when_missing
    result = @patcher.patch!
    assert result.appended
    assert_includes File.read(gitignore_path), "app/assets/javascripts/ux_manifests/*.js"
  end

  def test_is_idempotent_and_does_not_double_append
    @patcher.patch!
    result = ReactManifest::GitignorePatcher.new(@config).patch!
    refute result.appended
    occurrences = File.read(gitignore_path).scan("app/assets/javascripts/ux_manifests/*.js").size
    assert_equal 1, occurrences
  end

  def test_respects_existing_entry_in_a_populated_gitignore
    File.write(gitignore_path, "/log\napp/assets/javascripts/ux_manifests/*.js\n/tmp\n")
    result = @patcher.patch!
    refute result.appended
  end

  def test_creates_keep_in_manifest_dir
    @patcher.patch!
    assert File.exist?(File.join(@config.abs_manifest_dir, ".keep"))
  end

  def test_appends_with_leading_newline_when_file_lacks_trailing_newline
    File.write(gitignore_path, "/log")
    @patcher.patch!
    content = File.read(gitignore_path)
    assert_includes content, "/log\napp/assets/javascripts/ux_manifests/*.js"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/gitignore_patcher_test.rb`
Expected: FAIL — `uninitialized constant ReactManifest::GitignorePatcher`

- [ ] **Step 3: Write minimal implementation**

Create `lib/react_manifest/gitignore_patcher.rb`:

```ruby
require "fileutils"

module ReactManifest
  # Ensures the generated manifest dir is gitignored and that a committed .keep
  # keeps the directory present on a fresh clone. Idempotent and best-effort:
  # a filesystem error logs a warning and never raises.
  class GitignorePatcher
    include ReactManifest::Logging

    Result = Struct.new(:appended, :keep_created, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    def patch!
      Result.new(appended: ensure_gitignore_entry, keep_created: ensure_keep)
    end

    # Path (relative to Rails.root) that should be ignored, e.g.
    # "app/assets/javascripts/ux_manifests/*.js".
    def pattern
      subdir = @config.normalized_manifest_subdir
      base   = subdir.empty? ? @config.output_dir : File.join(@config.output_dir, subdir)
      File.join(base, "*.js")
    end

    private

    def gitignore_path
      Rails.root.join(".gitignore").to_s
    end

    def ensure_gitignore_entry
      path    = gitignore_path
      line    = pattern
      content = File.exist?(path) ? File.read(path, encoding: "utf-8") : ""
      return false if content.split("\n").map(&:strip).include?(line)

      prefix = content.empty? || content.end_with?("\n") ? "" : "\n"
      File.open(path, "a") { |f| f.write("#{prefix}#{line}\n") }
      log_info "Added #{line} to .gitignore"
      true
    rescue Errno::EACCES, Errno::ENOENT => e
      log_warn "Could not update .gitignore: #{e.message}"
      false
    end

    def ensure_keep
      dir  = @config.abs_manifest_dir
      keep = File.join(dir, ".keep")
      return false if File.exist?(keep)

      FileUtils.mkdir_p(dir)
      FileUtils.touch(keep)
      true
    rescue Errno::EACCES => e
      log_warn "Could not create #{dir}/.keep: #{e.message}"
      false
    end
  end
end
```

Add the require in `lib/react_manifest.rb` (with the other patcher requires, after `sprockets_manifest_patcher`):

```ruby
require "react_manifest/gitignore_patcher"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/gitignore_patcher_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/gitignore_patcher.rb lib/react_manifest.rb test/react_manifest/gitignore_patcher_test.rb
git commit -m "feat: GitignorePatcher ensures gitignored manifest dir + .keep"
```

---

### Task 3: `ReactManifest.reconcile_gitignore!` — guarded wrapper with untrack hint

This is the testable seam the Railtie and setup task both call. It honors `manage_gitignore?` and, when it actually appends the entry (i.e. the dir was previously tracked), logs a one-time hint to untrack the now-ignored files.

**Files:**
- Modify: `lib/react_manifest.rb` (add module method)
- Test: `test/react_manifest/reconcile_test.rb` (new)

- [ ] **Step 1: Write the failing test**

Create `test/react_manifest/reconcile_test.rb`:

```ruby
require "test_helper"

class ReconcileGitignoreTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def gitignore_path
    Rails.root.join(".gitignore").to_s
  end

  def test_reconcile_adds_entry_when_managed
    ReactManifest.reconcile_gitignore!(@config)
    assert_includes File.read(gitignore_path), "app/assets/javascripts/ux_manifests/*.js"
  end

  def test_reconcile_is_noop_when_management_disabled
    @config.manage_gitignore = false
    ReactManifest.reconcile_gitignore!(@config)
    refute File.exist?(gitignore_path)
  end

  def test_reconcile_returns_whether_it_appended
    assert_equal true, ReactManifest.reconcile_gitignore!(@config)
    assert_equal false, ReactManifest.reconcile_gitignore!(@config)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/reconcile_test.rb`
Expected: FAIL — `undefined method 'reconcile_gitignore!'`

- [ ] **Step 3: Write minimal implementation**

In `lib/react_manifest.rb`, add to the `class << self` block (near `resolve_bundles`):

```ruby
    # Ensure the manifest dir is gitignored (and .keep present). Honors
    # config.manage_gitignore. Returns true if it appended the .gitignore entry.
    # When it does, it also logs a one-time hint to untrack previously-committed
    # manifests (the gem never runs git itself).
    def reconcile_gitignore!(config = configuration)
      return false unless config.manage_gitignore?

      result = GitignorePatcher.new(config).patch!
      if result.appended
        subdir = config.normalized_manifest_subdir
        base   = subdir.empty? ? config.output_dir : File.join(config.output_dir, subdir)
        Logging.log_info(
          config,
          "If #{base}/*.js were previously committed, untrack them once: " \
          "git rm --cached #{base}/*.js"
        )
      end
      result.appended
    rescue StandardError => e
      Logging.log_warn(config, "gitignore reconcile skipped: #{e.message}")
      false
    end
```

**Note:** `Logging` is a mixin with instance methods `log_info`/`log_warn`. Add module-level convenience methods so callers without the mixin can log. In `lib/react_manifest/logging.rb`, add inside `module Logging`:

```ruby
    module_function

    def log_info(config, message)
      Formatter.emit(config, :info, message)
    end

    def log_warn(config, message)
      Formatter.emit(config, :warn, message)
    end
```

If `logging.rb` does not already centralize emission, instead inline the simplest form that matches the existing `log_info` body. Inspect `lib/react_manifest/logging.rb:9-20` first and mirror its exact emission (Rails.logger + optional stdout) in the two module functions. Keep the mixin instance methods unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/reconcile_test.rb`
Expected: PASS

- [ ] **Step 5: Run full suite (ensure logging change didn't break anything)**

Run: `bundle exec rake test TEST=test/react_manifest/logging_test.rb && bundle exec rake test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/react_manifest.rb lib/react_manifest/logging.rb test/react_manifest/reconcile_test.rb
git commit -m "feat: ReactManifest.reconcile_gitignore! with untrack hint"
```

---

### Task 4: Call reconcile from the Railtie boot step (dev-only) and from setup

**Files:**
- Modify: `lib/react_manifest/railtie.rb:10-31` (dev boot `ensure_manifests`)
- Modify: `tasks/react_manifest.rake:70-86` (setup task, after generation)

- [ ] **Step 1: Extend the dev boot step**

In `railtie.rb`, inside the `initializer "react_manifest.ensure_manifests"` block, after the generation `begin/rescue`, add a second guarded reconcile (still inside `next unless Rails.env.development?`):

```ruby
      begin
        ReactManifest.reconcile_gitignore!(config)
      rescue StandardError => e
        Rails.logger&.warn("[ReactManifest] gitignore reconcile failed: #{e.message}")
      end
```

This runs **only** in development (the `next unless Rails.env.development?` guard at the top of the initializer already applies), satisfying the "production never mutates the tree at boot" boundary.

- [ ] **Step 2: Wire setup to reconcile + print the untrack command**

In `tasks/react_manifest.rake`, in the `setup` task after step 5 (generate) and before "Done", add a step 6:

```ruby
    # 6. Ensure generated manifests are gitignored
    puts "\n6) Gitignoring generated manifests..."
    if config.manage_gitignore?
      patcher = ReactManifest::GitignorePatcher.new(config)
      result  = patcher.patch!
      if result.appended
        puts "   ✓ added #{patcher.pattern} to .gitignore"
        puts "   → one-time cleanup for previously-committed manifests:"
        puts "     git rm --cached #{File.dirname(patcher.pattern)}/*.js"
      else
        puts "   ✓ #{patcher.pattern} already ignored"
      end
    else
      puts "   (skipped — config.manage_gitignore is false)"
    end
```

- [ ] **Step 3: Manually verify the boot path with a smoke check**

Since the Railtie isn't loaded by the unit harness, verify the wiring compiles and the seam works:

Run: `ruby -Ilib -e 'require "react_manifest"; puts ReactManifest.respond_to?(:reconcile_gitignore!)'`
Expected: `true`

Run: `bundle exec rake test`
Expected: PASS (no regressions).

- [ ] **Step 4: Commit**

```bash
git add lib/react_manifest/railtie.rb tasks/react_manifest.rake
git commit -m "feat: reconcile gitignore on dev boot and in react_manifest:setup"
```

---

### Task 5: Upgrade-safety behavior tests (regenerate + reconcile invariants)

**Files:**
- Test: `test/react_manifest/reconcile_test.rb` (extend), `test/react_manifest/gitignore_patcher_test.rb` (extend)

- [ ] **Step 1: Write the tests**

Append to `ReconcileGitignoreTest`:

```ruby
  def test_old_format_manifests_are_regenerated_on_run
    # Seed a stale, hand-written manifest that references a file that no longer exists.
    dir = @config.abs_manifest_dir
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "ux_shared.js"),
               "// AUTO-GENERATED — DO NOT EDIT\n//= require ux/lib/gone_file\n")

    ReactManifest::Generator.new(@config).run!

    refute_includes File.read(File.join(dir, "ux_shared.js")), "gone_file"
  end

  def test_reconcile_idempotent_second_boot_appends_nothing
    ReactManifest.reconcile_gitignore!(@config)
    before = File.read(gitignore_path)
    ReactManifest.reconcile_gitignore!(@config)
    assert_equal before, File.read(gitignore_path)
  end

  def test_reconcile_survives_unwritable_gitignore
    FileUtils.mkdir_p(File.dirname(gitignore_path))
    # Make .gitignore a directory so a write fails; reconcile must not raise.
    FileUtils.mkdir_p(gitignore_path)
    assert_nothing_raised { ReactManifest.reconcile_gitignore!(@config) }
  ensure
    FileUtils.rm_rf(gitignore_path)
  end
```

Append to `GitignorePatcherTest`:

```ruby
  def test_keep_is_not_recreated_when_present
    @patcher.patch!
    result = ReactManifest::GitignorePatcher.new(@config).patch!
    refute result.keep_created
  end
```

**Note on prod no-op:** the "production performs no `.gitignore` mutation" guarantee is enforced by the Railtie's `next unless Rails.env.development?`, not by the patcher. It is verified by inspection of Task 4 Step 1 (the reconcile call sits under that guard). No unit test is added because the harness does not load the Railtie; if a Railtie test harness is later added, assert `reconcile_gitignore!` is not called when `Rails.env.production?`.

- [ ] **Step 2: Run the tests**

Run: `bundle exec rake test TEST=test/react_manifest/reconcile_test.rb && bundle exec rake test TEST=test/react_manifest/gitignore_patcher_test.rb`
Expected: PASS. (`assert_nothing_raised` is available via minitest; if not, wrap in a begin/rescue that flunks on error.)

- [ ] **Step 3: Commit**

```bash
git add test/react_manifest/reconcile_test.rb test/react_manifest/gitignore_patcher_test.rb
git commit -m "test: upgrade-safety — regenerate, idempotent reconcile, resilience"
```

---

### Task 6: Ship — changelog, docs, rubocop

**Files:**
- Modify: `CHANGELOG.md`, `CLAUDE.md`

- [ ] **Step 1: Changelog entry**

Under `## [Unreleased]`:

```markdown
### Changed
- Generated `ux_manifests/*.js` are now treated as build artifacts. `react_manifest:setup`
  and the development boot step add them to `.gitignore` (idempotently) and keep a
  committed `.keep` so the directory always exists; setup prints a one-time
  `git rm --cached` to untrack previously-committed manifests. Production is unaffected
  (manifests regenerate during `assets:precompile`). Opt out with
  `config.manage_gitignore = false`. Upgrading an existing app requires no manual step:
  the first dev boot regenerates manifests and ensures the ignore entry.
```

- [ ] **Step 2: Architecture note in CLAUDE.md**

In the Railtie section, add a bullet:

```markdown
- In development, also reconciles `.gitignore` (adds the manifest-dir ignore entry if
  missing) via `ReactManifest.reconcile_gitignore!` / `GitignorePatcher`. Dev-only;
  production never writes to the app tree at boot.
```

- [ ] **Step 3: Rubocop + full suite**

Run: `bundle exec rubocop --parallel && bundle exec rake test`
Expected: no offenses, all green.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: changelog + architecture note for gitignored manifests & upgrade reconcile"
```

---

## Self-Review

- **Spec coverage:** §4 Approach A (Task 2 patcher, in-place location, `.keep`); §4.1 production safety (no boot mutation in prod — Task 4 guard + note); §4.2 reconcile on boot (Task 4), `manage_gitignore` (Task 1), untrack-hint-not-action (Task 3); §5.12 tests 27–31 (Task 2 idempotent append, `.keep`, generation-location unchanged, fresh-clone via `.keep`, untrack printed not run — Task 4 Step 2); §5.13 tests 32–41 (Task 5: old-format regenerate, idempotent reconcile, opt-out, `.keep`, resilience; prod no-op by inspection).
- **Placeholder scan:** none — the one "inspect `logging.rb` and mirror" instruction in Task 3 Step 3 is a concrete adaptation directive with a fallback, not a TODO. Confirm the two module functions match the existing emission before committing.
- **Type/name consistency:** `GitignorePatcher#patch!` returns `Result(appended:, keep_created:)`, used consistently in Tasks 2–5; `reconcile_gitignore!` returns the boolean `appended`; `pattern` returns the relative ignore string, reused for the `git rm --cached` message.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-15-internal-manifests-upgrade.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks.

**2. Inline Execution** — execute tasks in this session with checkpoints.

**Which approach, and do you want to run the auto-promotion plan first (it fixes the runtime errors) or this one first?**
