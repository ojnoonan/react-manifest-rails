# Auto-Promotion of Shared Components — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a component defined under `ux/app/<controller>/` but used by other bundles load exactly once per page (via `ux_shared`) instead of being inlined into every consumer, eliminating duplicate-declaration and cascading `undefined` runtime errors — with no file moves.

**Architecture:** The generator already builds a symbol→bundle graph. We extend it to symbol→file granularity, compute a `promoted_files` set (files whose symbols are used outside their owning bundle, transitively closed), emit those into `ux_shared`, and exclude them from controller and `always_include` requires — enforcing "every file is emitted into exactly one bundle." Gated by `config.auto_shared` (default `true`); when `false`, the prior inline behavior is preserved verbatim.

**Tech Stack:** Ruby, Minitest, the gem's `SymbolExtractor` (regex or mini_racer AST), the `with_temp_rails_root`/`ReactManifestTest` fixture harness.

**Spec:** `docs/superpowers/specs/2026-07-15-hands-free-bundles-design.md` (Feature 1, §3; tests §5.1–5.11).

---

### Task 1: Add `config.auto_shared` flag

**Files:**
- Modify: `lib/react_manifest/configuration.rb:99-116` (initialize), add predicate near `dry_run?`
- Test: `test/react_manifest/configuration_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/react_manifest/configuration_test.rb`:

```ruby
def test_auto_shared_defaults_to_true
  assert_equal true, ReactManifest::Configuration.new.auto_shared?
end

def test_auto_shared_can_be_disabled
  config = ReactManifest::Configuration.new
  config.auto_shared = false
  assert_equal false, config.auto_shared?
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/configuration_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'auto_shared?'`

- [ ] **Step 3: Write minimal implementation**

In `configuration.rb`, add the accessor with the other `attr_accessor`s (near `:always_include`):

```ruby
    # When true (default), a component defined under app_dir but used by any other
    # bundle is emitted into the shared bundle (loaded once per page) instead of
    # being inlined into each consumer. Set false to restore legacy inlining.
    attr_accessor :auto_shared
```

In `initialize`, add after `@shared_bundle = "ux_shared"`:

```ruby
      @auto_shared       = true
```

Add the predicate after `dry_run?`:

```ruby
    def auto_shared?
      !!@auto_shared
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/configuration_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/configuration.rb test/react_manifest/configuration_test.rb
git commit -m "feat: add config.auto_shared flag (default true)"
```

---

### Task 2: Thread `shared_dirs` into the controller context and build symbol/file/usage maps

This task is a **pure refactor** — no output change. It restructures `build_controller_context` to track, per file, the symbols it defines and uses, plus which bundles use each symbol. `promoted_files` is added to the returned hash but left empty here (populated in Task 3).

**Files:**
- Modify: `lib/react_manifest/generator.rb:50-73` (`run!`), `:120-137` (`build_controller`), `:139-218` (`build_controller_context`)
- Test: `test/react_manifest/generator_test.rb` (existing suite must stay green)

- [ ] **Step 1: Write the failing test**

Add to `test/react_manifest/generator_test.rb` (inside `GeneratorRunTest`):

```ruby
def test_controller_context_exposes_empty_promoted_files_when_refactor_lands
  context = @generator.send(:build_controller_context,
                            @generator.instance_variable_get(:@classifier).classify.controller_dirs,
                            @generator.instance_variable_get(:@classifier).classify.shared_dirs)
  assert_kind_of Set, context[:promoted_files]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/generator_test.rb`
Expected: FAIL — `ArgumentError: wrong number of arguments` (context takes one arg) or missing `:promoted_files` key.

- [ ] **Step 3: Write minimal implementation**

In `run!`, change the context call (line ~52) and the `build_shared` call to pass shared dirs:

```ruby
    def run!
      classification = @classifier.classify
      controller_context = build_controller_context(classification.controller_dirs, classification.shared_dirs)

      # Phase 1: build all content in memory — no I/O.
      shared_manifest = build_shared(classification.shared_dirs, controller_context[:promoted_files])
      manifests = [shared_manifest] + classification.controller_dirs.map do |ctrl|
        build_controller(ctrl, controller_context)
      end

      migrate_legacy_manifests!

      results = manifests.map { |m| write_manifest(m[:filename], m[:content]) }

      expected_filenames = manifests.map { |m| m[:filename] }
      results.concat(remove_orphaned_manifests(expected_filenames))

      print_summary(results) if @config.verbose?
      results
    end
```

Replace `build_controller_context` (lines 139-218) with the refactored version. It keeps all existing return keys and adds `promoted_files` (empty for now) and internal maps:

```ruby
    def build_controller_context(controller_dirs, shared_dirs)
      bundle_files = {}
      file_owner = {}
      file_defs = Hash.new { |h, k| h[k] = Set.new }
      file_uses = Hash.new { |h, k| h[k] = Set.new }
      symbol_to_bundle = {}
      symbol_to_file = {}
      bundle_own_symbols = Hash.new { |h, k| h[k] = Set.new }
      symbol_used_by_bundles = Hash.new { |h, k| h[k] = Set.new }
      external_symbol_to_require = {}
      dependencies = Hash.new { |h, k| h[k] = Set.new }
      external_requires = Hash.new { |h, k| h[k] = Set.new }

      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in(ctrl[:path])
        bundle_files[bundle_name] = files
        isolated = @config.isolated_app_dirs.include?(ctrl[:name])

        files.each do |file_path|
          file_owner[file_path] = bundle_name
          extract_defined_symbols(file_path).each do |sym|
            next unless sym.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            file_defs[file_path] << sym
            unless isolated
              symbol_to_bundle[sym] ||= bundle_name
              symbol_to_file[sym]   ||= file_path
            end
            bundle_own_symbols[bundle_name] << sym
          end
        end
      end

      # Record symbol usage from controller files (per-file and per-bundle).
      bundle_files.each do |bundle_name, files|
        files.each do |file_path|
          extract_used_component_symbols(file_path).each do |sym|
            file_uses[file_path] << sym
            symbol_used_by_bundles[sym] << bundle_name
          end
        end
      end

      # A shared-dir file that uses a controller symbol forces that symbol's file
      # to be shared too (shared code loads on every page). Attribute those usages
      # to a pseudo-bundle so they count as "external" to any controller.
      shared_dirs.each do |dir|
        js_files_in(dir[:path]).each do |file_path|
          extract_used_component_symbols(file_path).each do |sym|
            symbol_used_by_bundles[sym] << @config.shared_bundle
          end
        end
      end

      # Index symbols from external_roots dirs
      @config.external_roots.each do |root_path|
        abs_root = abs_external_root(root_path)
        external_js_files_in(abs_root).each do |file_path|
          req_path = relative_require_path(file_path)
          warn_on_external_controller_references(file_path, symbol_to_bundle)
          extract_defined_symbols(file_path).each do |sym|
            external_symbol_to_require[sym] ||= req_path
          end
        end
      end

      # Explicit external_providers win over scanned roots on symbol conflicts
      @config.external_providers.each do |sym, req_path|
        external_symbol_to_require[sym] = req_path
      end

      # Cross-app dependency graph + external requires (dependencies kept for reporting).
      bundle_files.each do |bundle_name, files|
        own_symbols = bundle_own_symbols[bundle_name]
        files.each do |file_path|
          file_uses[file_path].each do |sym|
            next if own_symbols.include?(sym)

            dep_bundle = symbol_to_bundle[sym]
            dependencies[bundle_name] << dep_bundle if dep_bundle && dep_bundle != bundle_name

            req_path = external_symbol_to_require[sym]
            external_requires[bundle_name] << req_path if req_path
          end
        end
      end

      promoted_files = Set.new

      always_include_requires =
        build_always_include_requires(bundle_files, dependencies, promoted_files)

      {
        bundle_files: bundle_files,
        dependencies: dependencies,
        always_include_requires: always_include_requires,
        external_requires: external_requires,
        promoted_files: promoted_files
      }
    end
```

Update `build_always_include_requires` (lines 248-272) to accept and honor `promoted_files`:

```ruby
    def build_always_include_requires(bundle_files, dependencies, promoted_files)
      bundles = @config.always_include.map(&:to_s).reject(&:empty?).uniq
      return Hash.new { |h, k| h[k] = [] } if bundles.empty?

      requires_by_bundle = Hash.new { |h, k| h[k] = [] }

      bundle_files.each_key do |bundle_name|
        requires = Set.new

        bundles.each do |always_bundle|
          next if always_bundle == bundle_name

          transitive = [always_bundle] + transitive_dependencies(always_bundle, dependencies)
          transitive.each do |dep_bundle|
            bundle_files.fetch(dep_bundle, []).each do |abs_path|
              next if promoted_files.include?(abs_path)

              requires << relative_require_path(abs_path)
            end
          end
        end

        requires_by_bundle[bundle_name] = requires.to_a.sort
      end

      requires_by_bundle
    end
```

Update `build_shared` (lines 101-116) to accept promoted files:

```ruby
    def build_shared(shared_dirs, promoted_files = Set.new)
      lines = header_lines
      reqs = (shared_dirs.flat_map { |d| js_files_in(d[:path]) } + promoted_files.to_a)
             .map { |f| normalize_require_path(relative_require_path(f)) }
             .uniq
             .sort

      if reqs.empty?
        lines << "// (no shared JS files found)"
      else
        reqs.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{@config.shared_bundle}.js", content: "#{lines.join("\n")}\n" }
    end
```

Update `build_controller` (lines 120-137) to exclude promoted files and only inline cross-app deps in legacy mode:

```ruby
    def build_controller(ctrl, controller_context)
      lines = header_lines
      promoted = controller_context[:promoted_files]
      always_include_reqs = controller_context[:always_include_requires].fetch(ctrl[:bundle_name], [])
      dep_requires = if @config.auto_shared?
                       []
                     else
                       controller_dependency_requires(ctrl[:bundle_name], controller_context)
                     end
      ext_reqs = controller_context[:external_requires].fetch(ctrl[:bundle_name], Set.new).to_a.sort

      files = js_files_in(ctrl[:path]).reject { |f| promoted.include?(f) }
      own_requires = files.map { |f| relative_require_path(f) }
      all_requires = (always_include_reqs + dep_requires + ext_reqs + own_requires).uniq

      if all_requires.empty?
        lines << "// (no JSX files found in #{ctrl[:name]}/)"
      else
        all_requires.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{ctrl[:bundle_name]}.js", content: "#{lines.join("\n")}\n" }
    end
```

- [ ] **Step 4: Run the full suite to verify it stays green**

Run: `bundle exec rake test`
Expected: PASS. (Behavior is unchanged because `promoted_files` is empty and `auto_shared?` only skips `dep_requires` — which Task 3 re-enables via promotion. NOTE: the existing test `test_includes_dependent_controller_files_when_main_uses_component_from_another_app_dir` will now FAIL because `dep_requires` is skipped under the default. This is expected and fixed in Task 5. If you are running task-by-task, temporarily set `config.auto_shared = false` at the top of that single test to keep the suite green until Task 5; the diff is reverted there.)

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/generator.rb test/react_manifest/generator_test.rb
git commit -m "refactor: track symbol->file and per-file usage in controller context"
```

---

### Task 3: Compute the promoted-files set (direct + transitive)

**Files:**
- Modify: `lib/react_manifest/generator.rb` (add `compute_promoted_files`, populate in `build_controller_context`)
- Test: `test/react_manifest/generator_promotion_test.rb` (new)

- [ ] **Step 1: Write the failing test**

Create `test/react_manifest/generator_promotion_test.rb`:

```ruby
require "test_helper"

class GeneratorPromotionTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def write_ux(rel, content)
    path = Rails.root.join("app/assets/javascripts/ux", rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def read_manifest(name)
    File.read(File.join(@config.abs_manifest_dir, name), encoding: "utf-8")
  end

  def test_component_used_by_another_controller_is_promoted_to_shared
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_reports.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_common.js"), "ux/app/common/export_form"
  end

  def test_private_component_stays_in_its_own_bundle
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ReportsPrivate />;\n")
    write_ux("app/reports/reports_private.js.jsx", "const ReportsPrivate = () => <div />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_reports.js"), "ux/app/reports/reports_private"
    refute_includes read_manifest("ux_shared.js"), "ux/app/reports/reports_private"
  end

  def test_transitive_dependency_of_a_promoted_file_is_also_promoted
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <ExportRow />;\n")
    write_ux("app/common/export_row.js.jsx", "const ExportRow = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_row"
  end

  def test_mutual_use_cycle_terminates_and_promotes_both
    write_ux("app/common/alpha.js.jsx", "const Alpha = () => <Beta />;\n")
    write_ux("app/common/beta.js.jsx",  "const Beta = () => <Alpha />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Alpha />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/alpha"
    assert_includes read_manifest("ux_shared.js"), "ux/app/common/beta"
  end

  def test_diamond_dependency_promotes_shared_leaf_once
    write_ux("app/common/leaf.js.jsx", "const Leaf = () => <div />;\n")
    write_ux("app/common/top_a.js.jsx", "const TopA = () => <Leaf />;\n")
    write_ux("app/common/top_b.js.jsx", "const TopB = () => <Leaf />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div><TopA /><TopB /></div>;\n")

    ReactManifest::Generator.new(@config).run!

    shared = read_manifest("ux_shared.js")
    assert_equal 1, shared.scan("ux/app/common/leaf\n").size + shared.scan("ux/app/common/leaf$").size,
                 "leaf should be required exactly once"
    assert_equal 1, shared.lines.count { |l| l.strip == "//= require ux/app/common/leaf" }
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/generator_promotion_test.rb`
Expected: FAIL — promoted files are not yet in `ux_shared` (set is empty).

- [ ] **Step 3: Write minimal implementation**

In `build_controller_context`, replace `promoted_files = Set.new` with:

```ruby
      promoted_files =
        if @config.auto_shared?
          compute_promoted_files(file_owner, file_defs, file_uses,
                                 symbol_used_by_bundles, symbol_to_file)
        else
          Set.new
        end
```

Add the helper (place it right after `build_controller_context`):

```ruby
    # A controller file is promoted to the shared bundle when a symbol it defines
    # is used by any bundle other than its owner (another controller, an
    # always_include bundle, or a shared-dir file), then transitively for anything
    # a promoted file itself depends on. Guarantees each file is emitted once.
    def compute_promoted_files(file_owner, file_defs, file_uses, symbol_used_by_bundles, symbol_to_file)
      promoted = Set.new

      file_owner.each do |file_path, owner|
        externally_used = file_defs[file_path].any? do |sym|
          (symbol_used_by_bundles[sym] - [owner]).any?
        end
        promoted << file_path if externally_used
      end

      worklist = promoted.to_a
      until worklist.empty?
        current = worklist.pop
        file_uses[current].each do |sym|
          dep_file = symbol_to_file[sym]
          next unless dep_file
          next if promoted.include?(dep_file)

          promoted << dep_file
          worklist << dep_file
        end
      end

      promoted
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/generator_promotion_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/react_manifest/generator.rb test/react_manifest/generator_promotion_test.rb
git commit -m "feat: promote cross-used app components into ux_shared (auto_shared)"
```

---

### Task 4: Single-emission invariant + isolated/external/always_include interaction tests

**Files:**
- Test: `test/react_manifest/generator_promotion_test.rb` (extend)

- [ ] **Step 1: Write the failing/there-to-guard tests**

Append to `GeneratorPromotionTest`:

```ruby
  # ---- single-emission invariant -------------------------------------------

  def requires_in(name)
    read_manifest(name).lines.filter_map do |l|
      l.strip.start_with?("//= require") ? l.strip.sub("//= require ", "") : nil
    end
  end

  def controller_manifest_names
    Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
       .map { |p| File.basename(p) }
       .reject { |n| n == "ux_shared.js" }
  end

  def test_no_require_appears_in_both_shared_and_a_controller_bundle
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    shared = requires_in("ux_shared.js").to_set
    controller_manifest_names.each do |name|
      overlap = shared & requires_in(name).to_set
      assert_empty overlap, "#{name} duplicates shared requires: #{overlap.to_a}"
    end
  end

  def test_no_require_appears_in_two_controller_bundles
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    write_ux("app/billing/billing_index.js.jsx", "const BillingIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    seen = {}
    controller_manifest_names.each do |name|
      requires_in(name).each do |req|
        assert_nil seen[req], "#{req} appears in #{seen[req]} and #{name}"
        seen[req] = name
      end
    end
  end

  # ---- regression: the reported navbar + always_include bug -----------------

  def test_navbar_always_include_no_longer_double_declares_shared_component
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/notification/show_component.js.jsx", "const Show = () => <div />;\n")
    write_ux("app/notification/notifications_index.js.jsx", "const NotificationsIndex = () => <div />;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Show />;\n")
    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/notification/show_component"
    refute_includes read_manifest("ux_navbar.js"), "ux/app/notification/show_component"
    refute_includes read_manifest("ux_notification.js"), "ux/app/notification/show_component"
    # notification-specific file stays put (not over-hoisted)
    assert_includes read_manifest("ux_notification.js"), "ux/app/notification/notifications_index"
  end

  # ---- isolated_app_dirs is never promoted ---------------------------------

  def test_isolated_app_dir_component_is_not_promoted
    ReactManifest.configure { |c| c.isolated_app_dirs = ["rvb"] }
    write_ux("app/rvb/rvb_show.js.jsx", "const Show = () => <div>rvb</div>;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <button>Show More</button>;\n")
    ReactManifest::Generator.new(@config).run!

    refute_includes read_manifest("ux_shared.js"), "ux/app/rvb/rvb_show"
    assert_includes read_manifest("ux_rvb.js"), "ux/app/rvb/rvb_show"
  end

  # ---- always_include private file still loads, not promoted ----------------

  def test_always_include_private_file_is_not_promoted_and_loads_everywhere
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <NavbarPrivate />;\n")
    write_ux("app/navbar/navbar_private.js.jsx", "const NavbarPrivate = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div />;\n")
    ReactManifest::Generator.new(@config).run!

    # navbar_private is used only inside navbar -> not promoted; stays in ux_navbar
    # and is force-included into other controllers via always_include.
    refute_includes read_manifest("ux_shared.js"), "ux/app/navbar/navbar_private"
    assert_includes read_manifest("ux_navbar.js"), "ux/app/navbar/navbar_private"
    assert_includes read_manifest("ux_reports.js"), "ux/app/navbar/navbar_private"
  end
```

- [ ] **Step 2: Run tests**

Run: `bundle exec rake test TEST=test/react_manifest/generator_promotion_test.rb`
Expected: PASS (these validate Task 3's implementation; no code change needed if the algorithm is correct).

- [ ] **Step 3: If any fail, fix the algorithm, not the test**

Follow `superpowers:systematic-debugging`. Most likely culprits: `symbol_used_by_bundles` not counting the always_include/shared pseudo-bundle, or `Set#-` receiving an Array (it does — `Set - Array` is valid in Ruby).

- [ ] **Step 4: Commit**

```bash
git add test/react_manifest/generator_promotion_test.rb
git commit -m "test: single-emission invariant + navbar regression + isolated/always_include cases"
```

---

### Task 5: Reconcile existing tests with the new default + backward-compat test

**Files:**
- Modify: `test/react_manifest/generator_test.rb:68-87` (the cross-app inline test)
- Test: `test/react_manifest/generator_promotion_test.rb` (add `auto_shared=false` case)

- [ ] **Step 1: Update the existing inline test to assert promotion under the new default**

Replace `test_includes_dependent_controller_files_when_main_uses_component_from_another_app_dir` (lines 68-87) with:

```ruby
  def test_promotes_cross_app_component_into_shared_under_default
    dep_dir = Rails.root.join("app/assets/javascripts/ux/app/design_variables")
    main_dir = Rails.root.join("app/assets/javascripts/ux/app/main")
    FileUtils.mkdir_p(dep_dir)
    FileUtils.mkdir_p(main_dir)

    File.write(dep_dir.join("design_variable_show.js.jsx"), "const DesignVariableShow = () => <div />;\n")
    main_index_content = <<~JS
      const MainIndex = () => <WidgetHost components={[
        DesignVariableShow,
      ]} />;
    JS
    File.write(main_dir.join("main_index.js.jsx"), main_index_content)

    @generator.run!

    # Cross-app component is promoted to shared, not inlined into the consumer.
    assert_includes read_manifest("ux_shared.js"), "ux/app/design_variables/design_variable_show"
    refute_includes read_manifest("ux_main.js"), "ux/app/design_variables/design_variable_show"
    assert_includes read_manifest("ux_main.js"), "ux/app/main/main_index"
  end
```

- [ ] **Step 2: Add the backward-compat test (legacy inline path preserved)**

Append to `GeneratorPromotionTest`:

```ruby
  def test_auto_shared_false_restores_legacy_inline_behavior
    ReactManifest.configure { |c| c.auto_shared = false }
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    # Legacy: cross-app dep inlined into the consumer, nothing promoted to shared.
    assert_includes read_manifest("ux_reports.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
  end
```

- [ ] **Step 3: Run the full suite**

Run: `bundle exec rake test`
Expected: PASS across all files. If `test_inlines_always_include_bundle_files_into_controller_manifests` fails, confirm `main_index`/`users_index` are single-owner (they are) — it should still pass because always_include inlining of non-promoted files is retained.

- [ ] **Step 4: Commit**

```bash
git add test/react_manifest/generator_test.rb test/react_manifest/generator_promotion_test.rb
git commit -m "test: reconcile inline test with promotion default; guard auto_shared=false"
```

---

### Task 6: Promotions report in `react_manifest:analyze`

**Files:**
- Modify: `lib/react_manifest/dependency_map.rb` (add promotions accessor/print) OR `tasks/react_manifest.rake:123-133` (analyze task)
- Test: `test/react_manifest/generator_promotion_test.rb` (assert the context exposes promotions with reasons)

Because `DependencyMap` is built from `Scanner` output (not the generator context), expose promotion reasons directly from the generator and print them in the analyze task.

- [ ] **Step 1: Write the failing test**

Append to `GeneratorPromotionTest`:

```ruby
  def test_promotion_reasons_are_exposed_for_reporting
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    gen = ReactManifest::Generator.new(@config)
    reasons = gen.promotion_reasons
    key = "ux/app/common/export_form"
    assert reasons.key?(key), "expected #{key} in promotion reasons: #{reasons.keys}"
    assert_includes reasons[key], "ux_reports"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rake test TEST=test/react_manifest/generator_promotion_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'promotion_reasons'`.

- [ ] **Step 3: Implement `promotion_reasons`**

In `compute_promoted_files`, also record, for each promoted file, the set of bundles that forced it. Add an accessor. Change the signature to capture reasons into an instance variable, and expose a public method.

Add near the top of the `Generator` class (after `initialize`):

```ruby
    # After a run (or on demand), maps a promoted file's require path to the set of
    # bundle names that forced its promotion. Used by react_manifest:analyze.
    def promotion_reasons
      classification = @classifier.classify
      build_controller_context(classification.controller_dirs, classification.shared_dirs)
      @promotion_reasons || {}
    end
```

In `compute_promoted_files`, build reasons alongside promotion. Replace the direct-use loop with one that records reasons, and set `@promotion_reasons`:

```ruby
    def compute_promoted_files(file_owner, file_defs, file_uses, symbol_used_by_bundles, symbol_to_file)
      promoted = Set.new
      reasons = Hash.new { |h, k| h[k] = Set.new }

      file_owner.each do |file_path, owner|
        forcing = Set.new
        file_defs[file_path].each do |sym|
          (symbol_used_by_bundles[sym] - [owner]).each { |b| forcing << b }
        end
        next if forcing.empty?

        promoted << file_path
        reasons[relative_require_path(file_path)] = forcing
      end

      worklist = promoted.to_a
      until worklist.empty?
        current = worklist.pop
        file_uses[current].each do |sym|
          dep_file = symbol_to_file[sym]
          next unless dep_file
          next if promoted.include?(dep_file)

          promoted << dep_file
          reasons[relative_require_path(dep_file)] << "(transitive)"
          worklist << dep_file
        end
      end

      @promotion_reasons = reasons.transform_values(&:to_a)
      promoted
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/generator_promotion_test.rb`
Expected: PASS

- [ ] **Step 5: Print promotions in the analyze task**

In `tasks/react_manifest.rake`, at the end of the `analyze` task body (after `dep_map.print_report`), add:

```ruby
    reasons = ReactManifest::Generator.new(config).promotion_reasons
    unless reasons.empty?
      puts "\nPromotions (app/ components emitted into #{config.shared_bundle}):"
      reasons.sort.each do |req, bundles|
        puts "  #{req}  <- used by: #{bundles.sort.join(', ')}"
      end
    end
```

- [ ] **Step 6: Run the full suite + rubocop**

Run: `bundle exec rake test && bundle exec rubocop --parallel`
Expected: PASS, no offenses. Fix any `Metrics/MethodLength`/`AbcSize` offenses by extracting the reasons-building into a small private helper if flagged.

- [ ] **Step 7: Commit**

```bash
git add lib/react_manifest/generator.rb tasks/react_manifest.rake test/react_manifest/generator_promotion_test.rb
git commit -m "feat: report auto-promoted components in react_manifest:analyze"
```

---

### Task 7: Changelog + docs

**Files:**
- Modify: `CHANGELOG.md` (add under `[Unreleased]`)
- Modify: `CLAUDE.md` architecture note (Generator bullet) and/or `README`

- [ ] **Step 1: Add the changelog entry**

Under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
### Added
- Auto-promotion: a component defined under `ux/app/<controller>/` but used by any
  other bundle is now emitted into `ux_shared` (loaded once per page) instead of being
  inlined into each consumer. This eliminates duplicate top-level `const` declarations
  ("Identifier X has already been declared") — and the cascading `X is not defined`
  errors that follow when a SyntaxError aborts a concatenated bundle — for components
  shared across controllers (e.g. a navbar component pulled in via `always_include`).
  Files never move; only the `//= require` line's destination changes. Promotion is
  transitive. `react_manifest:analyze` now lists what was promoted and why. Set
  `config.auto_shared = false` to restore the previous inline behavior.
```

- [ ] **Step 2: Update the architecture note**

In `CLAUDE.md`, in the `Generator` bullet, append a sentence:

```markdown
   With `config.auto_shared` (default on), a controller-owned file used by any other
   bundle is promoted into `ux_shared` (transitively) so each file is emitted into
   exactly one bundle; `auto_shared = false` restores legacy cross-app inlining.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: changelog + architecture note for auto-promotion"
```

---

## Self-Review

- **Spec coverage (§5.1–5.11):** private (Task 3), cross-use (Task 3), transitive/cycle/diamond (Task 3), shared-dir-uses-controller-symbol (implemented via the shared pseudo-bundle in Task 2; add an explicit test if desired), single-emission invariant (Task 4), regression (Task 4), isolated (Task 4), always_include private + promoted-excluded (Task 4), backward-compat `auto_shared=false` (Task 5), reporting (Task 6). external_roots/external_providers behavior is unchanged (Task 2 preserves that code path); determinism is covered by sorted output + existing idempotency test. **Gap check:** §5.10 (AST vs regex parity) is implicitly covered since mini_racer is always present in the suite; add a regex-only variant only if `SymbolExtractor` gains a toggle.
- **Placeholder scan:** none — every step has concrete code/commands.
- **Type/name consistency:** `promoted_files` (Set) and `promotion_reasons` (Hash of require-path → Array) are used consistently; `build_shared`/`build_controller_context`/`build_always_include_requires` signatures match every call site updated in Task 2.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-15-auto-promotion.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task with review between tasks.

**2. Inline Execution** — execute tasks in this session with checkpoints.

**Which approach?** (A companion plan for internal-manifests + upgrade-safety follows.)
