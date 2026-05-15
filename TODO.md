# TODO

Peer review findings for `react-manifest-rails`. Issues are grouped by priority.

---

## Critical / Release-Blocking

- [~] **Detect circular dependencies between bundles** — N/A for current architecture
  - The generator produces a flat two-tier structure (shared → controllers); cross-controller requires are never generated, making circular deps architecturally impossible in current output
  - Revisit if cross-bundle requires are ever introduced

- [x] **TypeScript extension stripping missing in `relative_require_path` / `normalize_require_path`** ([scanner.rb:190](lib/react_manifest/scanner.rb#L190), [generator.rb:352](lib/react_manifest/generator.rb#L352), [generator.rb:464](lib/react_manifest/generator.rb#L464))
  - All three methods strip only `.js.jsx`, `.jsx`, `.js` — not `.ts` or `.tsx`
  - When `config.extensions` includes `ts`/`tsx`, require paths are emitted as `//= require ux/components/foo.tsx` (broken Sprockets directive) instead of `//= require ux/components/foo`
  - Fix: extend each `sub` chain to also strip `.ts.tsx`, `.tsx`, and `.ts`; add a regression spec

- [ ] **`clean` rake task has unhandled TOCTOU around `File.foreach`** ([react_manifest.rake:162](tasks/react_manifest.rake#L162))
  - `Dir.glob` then `File.foreach(file).first` with no rescue — if a file is deleted between the glob and the read, raises `Errno::ENOENT` and aborts the task
  - Fix: wrap in `rescue Errno::ENOENT` (same pattern as `Generator#auto_generated?`)

---

## Performance

- [ ] **Cache the symbol index between regenerations** ([scanner.rb:50-123](lib/react_manifest/scanner.rb#L50))
  - Every file-change event triggers a full rescan of all shared directories
  - Cache the symbol index and invalidate only the entries for the changed file

- [ ] **`component_maps` rescans all controller files on every `react_component` call** ([lib/react_manifest.rb:135](lib/react_manifest.rb#L135))
  - `resolve_bundles_for_component_direct` → `component_maps` runs a full `TreeClassifier` + file glob + symbol scan on every rendered `react_component` tag, with no memoization
  - In a view with multiple `react_component` calls this is O(files × components) per request
  - Fix: memoize `component_maps` result per-process (or per-request via `request.env`) and invalidate on configuration reset

- [ ] **Reduce Scanner to a single pass** ([scanner.rb](lib/react_manifest/scanner.rb))
  - Currently makes separate passes for shared dirs, controller dirs, and warning emission — can be collapsed into one traversal

---

## Test Coverage

- [ ] **Add integration tests**
  - Full generate → asset-pipeline compile flow using the dummy app
  - Watcher detects file change → regenerates correct manifest
  - Concurrent requests during regeneration (stress test)

- [ ] **Test large-scale inputs** — 100+ controllers, 500+ shared symbols, deeply nested namespaces

- [x] **Add TypeScript extension regression specs** ([spec/react_manifest/generator_spec.rb](spec/react_manifest/generator_spec.rb), [spec/react_manifest/scanner_spec.rb](spec/react_manifest/scanner_spec.rb))
  - Verify that `.ts` and `.tsx` source files produce require paths without raw extensions when `config.extensions = %w[js jsx ts tsx]`

---

## Code Quality / Low Priority

- [ ] **Unify logging strategy** — codebase mixes `puts`, `$stdout.puts`, `warn`, and `Rails.logger.info`; pick one and apply consistently ([watcher.rb:67-69](lib/react_manifest/watcher.rb#L67), [generator.rb:109](lib/react_manifest/generator.rb#L109), [tree_classifier.rb:19](lib/react_manifest/tree_classifier.rb#L19), [reporter.rb](lib/react_manifest/reporter.rb), [dependency_map.rb](lib/react_manifest/dependency_map.rb))

- [ ] **Remove dead private methods from `Scanner`** ([scanner.rb:317-335](lib/react_manifest/scanner.rb#L317))
  - `scan_component_usage` (line 317) and `scan_array_component_usage` (line 326) are never called
  - `scan_array_component_usage` references `ARRAY_COMPONENT_LIST_PATTERN` which is not defined anywhere — would raise `NameError` if called
  - Remove both methods; they are artifacts of a prior refactor

- [ ] **Remove dead expressions in `build_controller`** ([generator.rb:91-92](lib/react_manifest/generator.rb#L91))
  - Lines 91-92 evaluate `controller_context[:shared_lib_requires]` and `controller_context[:shared_requires].fetch(...)` but discard their return values — they contribute nothing and confuse readers
  - Remove the two dead-expression lines

- [ ] **Non-atomic writes in `LayoutPatcher` and `ApplicationMigrator`** ([layout_patcher.rb:66](lib/react_manifest/layout_patcher.rb#L66), [application_migrator.rb:71](lib/react_manifest/application_migrator.rb#L71))
  - Both use `File.write` directly — unlike `Generator`, they have no tmp+rename guard; a killed process leaves a partially-written layout or application.js
  - Apply the same atomic write pattern used in `Generator#write_manifest`

- [x] **Extract `relative_require_path` shared between `Scanner` and `Generator`** ([scanner.rb:185](lib/react_manifest/scanner.rb#L185), [generator.rb:347](lib/react_manifest/generator.rb#L347))
  - Identical implementation copied into two classes; any fix (e.g. TypeScript extension stripping above) must be applied in both places
  - Extract to a `ReactManifest::PathUtils` module included by both

- [ ] **CI Ruby matrix doesn't cover 3.0 / 3.1 despite gemspec requiring `>= 3.0.0`** ([ci.yml](.github/workflows/ci.yml), [gemspec](react-manifest-rails.gemspec#L18))
  - Matrix tests 3.2 and 3.3 only; either add 3.0/3.1 to the matrix or tighten the gemspec minimum to `>= 3.2` (the minimum Ruby with `Data.define` and pattern matching stable — or whichever version is actually tested)
