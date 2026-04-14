# TODO

Peer review findings for `react-manifest-rails`. Issues are grouped by priority.

---

## Critical / Release-Blocking

- [x] **Fix TOCTOU race condition in `auto_generated?`** ([generator.rb:176-182](lib/react_manifest/generator.rb#L176))
  - `File.exist?` check and subsequent `File.foreach` read are not atomic — file can be deleted between the two calls, raising `Errno::ENOENT`
  - Fix: wrap in a single `rescue Errno::ENOENT` block rather than checking existence first

- [x] **Add error handling to `File.read` in Scanner** ([scanner.rb:86](lib/react_manifest/scanner.rb#L86))
  - No rescue for `Errno::ENOENT` (file deleted between glob and read), `Errno::EACCES` (permission denied), or `Encoding::InvalidByteSequenceError` (non-UTF-8 source files)
  - `TreeClassifier` already guards permissions; `Scanner` should too

- [x] **Guard against inconsistent state on partial generation failure** ([generator.rb:31-45](lib/react_manifest/generator.rb#L31))
  - Manifests are written sequentially; if generation fails midway, previously written manifests reference a bundle that was never completed
  - Consider writing all files to temp paths and renaming atomically, or at minimum logging which manifests were written before failure

- [~] **Detect circular dependencies between bundles** — N/A for current architecture
  - The generator produces a flat two-tier structure (shared → controllers); cross-controller requires are never generated, making circular deps architecturally impossible in current output
  - Revisit if cross-bundle requires are ever introduced

---

## Packaging & Dependencies

- [x] **Reclassify `listen` as an optional dependency** ([react-manifest-rails.gemspec:36](react-manifest-rails.gemspec#L36), [watcher.rb:16-20](lib/react_manifest/watcher.rb#L16))
  - `listen` is listed as a runtime `add_dependency`, but `watcher.rb` rescues `LoadError` and silently disables watching — the gemspec and runtime behavior contradict each other
  - Move to `add_development_dependency`, or use `spec.add_dependency` with an explicit note, and update the README install instructions to show how to opt in for development

- [x] **Add upper bound to `railties` dependency** ([react-manifest-rails.gemspec:35](react-manifest-rails.gemspec#L35))
  - `">= 6.1"` allows Rails 8.x+ without any compatibility validation
  - Change to `">= 6.1", "< 9"` (or whatever range has been tested) to prevent silent breakage on future major versions

- [x] **Add missing gemspec metadata** ([react-manifest-rails.gemspec](react-manifest-rails.gemspec))
  - Missing `metadata["bug_tracker_uri"]`, `metadata["documentation_uri"]`, and `metadata["changelog_uri"]`
  - These surface on rubygems.org and improve discoverability

- [x] **Add `rubocop` to development dependencies** ([Gemfile](Gemfile))
  - `Rakefile` defines a `lint` task but `rubocop` is not in `Gemfile` — `bundle exec rake lint` fails for contributors

---

## CI/CD

- [x] **Add a push/PR-triggered workflow** ([.github/workflows/ci.yml](.github/workflows/ci.yml))
  - The only workflow triggers on `release` events; no automated checks run on pull requests or branch pushes
  - Add a separate `ci.yml` that runs tests and lint on every push to `main` and every PR

- [x] **Add linting to CI** — added `lint` job to [ci.yml](.github/workflows/ci.yml)

- [x] **Add test coverage reporting** — simplecov added to [spec_helper.rb](spec/spec_helper.rb); reports written to `coverage/`

- [x] **Add `bundler-audit` to CI** — `audit` job in [ci.yml](.github/workflows/ci.yml)

- [x] **Add Dependabot configuration** — [.github/dependabot.yml](.github/dependabot.yml)

---

## Missing Features

- [x] **Support TypeScript and TSX files** ([generator.rb:142](lib/react_manifest/generator.rb#L142))
  - Glob is hardcoded to `*.{js,jsx}`; `.ts` and `.tsx` files are ignored entirely
  - Add a `config.extensions` option (defaulting to `%w[js jsx]`) and use it everywhere globs are constructed

- [x] **Support ES module syntax in Scanner** ([scanner.rb:17-32](lib/react_manifest/scanner.rb#L17))
  - `DEFINITION_PATTERNS` only match CommonJS/variable-assignment style (`const Foo = ...`)
  - Missing: `export default function Foo`, `export const Bar = ...`, `export { Foo }`, and `import` tracking
  - Apps using native ESM will have silent dependency misses

- [x] **Make file extensions configurable** — `config.extensions = %w[js jsx ts tsx]` ([configuration.rb](lib/react_manifest/configuration.rb))

- [x] **Improve nested namespace resolution** ([lib/react_manifest.rb](lib/react_manifest.rb))
  - `controller_candidates` already appends the leaf segment (`ux_reports` for `admin/dashboard/reports`); added regression test in [view_helpers_spec.rb](spec/react_manifest/view_helpers_spec.rb)

---

## Test Coverage

- [x] **Add error scenario tests for Scanner**
  - File deleted between glob and read (`Errno::ENOENT`)
  - Permission denied (`Errno::EACCES`)
  - Non-UTF-8 source file (`Encoding::InvalidByteSequenceError`)
  - Invalid/unparseable JS content (should warn and continue, not crash)

- [x] **Add error scenario tests for Generator**
  - Disk full (`Errno::ENOSPC`) — should clean up temp file
  - Destination directory removed between `mkdir_p` and `rename`
  - `auto_generated?` called on a file deleted mid-check

- [x] **Add dedicated configuration spec**
  - Test default values
  - Test absolute vs relative path resolution (`abs_ux_root`, `abs_output_dir`)
  - Test invalid path inputs

- [ ] **Add integration tests**
  - Full generate → asset-pipeline compile flow using the dummy app
  - Watcher detects file change → regenerates correct manifest
  - Concurrent requests during regeneration (stress test)

- [x] **Add view helper edge-case tests** ([spec/react_manifest/view_helpers_spec.rb](spec/react_manifest/view_helpers_spec.rb))
  - `controller_path` is `nil` (non-controller context)
  - Called from a mailer (should return safe empty string)
  - Controller name with special characters or path segments that produce unusual bundle names

- [ ] **Test large-scale inputs** — 100+ controllers, 500+ shared symbols, deeply nested namespaces

---

## Performance

- [ ] **Cache the symbol index between regenerations** ([scanner.rb:50-123](lib/react_manifest/scanner.rb#L50))
  - Every file-change event triggers a full rescan of all shared directories
  - Cache the symbol index and invalidate only the entries for the changed file

- [x] **Add an inverted index to `DependencyMap#controllers_using`** ([dependency_map.rb:19-21](lib/react_manifest/dependency_map.rb#L19))
  - Current implementation is O(n×m): iterates all controller usages to find which ones include a given file
  - Build a reverse map `{ file → [controllers] }` once in the constructor for O(1) lookup

- [ ] **Reduce Scanner to a single pass** ([scanner.rb](lib/react_manifest/scanner.rb))
  - Currently makes separate passes for shared dirs, controller dirs, and warning emission — can be collapsed into one traversal

---

## Documentation

- [x] **Add a migration guide for existing projects**
  - Step-by-step: identify current `application.js` requires → run analyzer → validate → roll back plan
  - Before/after configuration examples

- [x] **Add a troubleshooting section to README**
  - "Bundle appears twice in HTML" → check `always_include` config
  - "Watcher stops responding after a while" → known issue / server restart
  - "Generator crashes on first run" → check directory permissions for `output_dir`

- [x] **Add YARD/RDoc comments to public classes**
  - `Scanner`, `Generator`, `Configuration`, `DependencyMap`, `Reporter` all have no inline API docs

- [x] **Document Rails and Ruby compatibility matrix**
  - README should state exactly which Rails and Ruby versions are tested and supported

- [x] **Document performance characteristics**
  - Expected generation time for small/medium/large projects
  - Watcher debounce latency
  - Memory footprint with a large symbol index

- [x] **Clarify `listen` installation instructions** — README should say whether `listen` is required and under what conditions

---

## Low Priority / Polish

- [ ] **Unify logging strategy** — codebase mixes `puts`, `$stdout.puts`, `warn`, and `Rails.logger.info`; pick one and apply consistently ([watcher.rb:67-69](lib/react_manifest/watcher.rb#L67), [generator.rb:109](lib/react_manifest/generator.rb#L109), [tree_classifier.rb:19](lib/react_manifest/tree_classifier.rb#L19))

- [x] **Handle symlinked directories in `TreeClassifier`** ([tree_classifier.rb:25-34](lib/react_manifest/tree_classifier.rb#L25))
  - `File.directory?` returns false for symlinks on some systems; use `File.directory?(File.realpath(path))`

- [x] **Expand `VENDOR_HINTS` in `ApplicationAnalyzer`** ([application_analyzer.rb:12-20](lib/react_manifest/application_analyzer.rb#L12))
  - Missing common libraries: `bootstrap`, `tailwindcss`, `axios`, `moment`, `date-fns`, `formik`, `react-hook-form`, `lodash`, `jquery`

- [x] **Reload watcher config on initializer change** ([watcher.rb](lib/react_manifest/watcher.rb)) — documented as known limitation in README
  - Changes to `config/initializers/react_manifest.rb` are ignored until server restart; at minimum document this limitation

- [x] **Sanitize terminal output in `DependencyMap#show`** ([dependency_map.rb:34](lib/react_manifest/dependency_map.rb#L34))
  - Symbol names printed raw; a symbol containing ANSI escape sequences could manipulate the terminal

- [x] **Document the `0.x` pre-release stability guarantee**
  - Add a brief note to README that the API is unstable before 1.0 and breaking changes may occur in minor versions

- [x] **Set restrictive permissions on `.bak` backup files** ([application_migrator.rb:54-65](lib/react_manifest/application_migrator.rb#L54))
  - Backup files are created with the default umask; add `File.chmod(0o600, bak_path)` after copy
