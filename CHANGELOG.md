# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Changed
- Generated `ux_manifests/*.js` are now treated as build artifacts. `react_manifest:setup`
  and the development boot step add them to `.gitignore` (idempotently) and keep a
  committed `.keep` so the directory always exists; setup prints a one-time
  `git rm --cached` to untrack previously-committed manifests. Production is unaffected
  (manifests regenerate during `assets:precompile`). Opt out with
  `config.manage_gitignore = false`. Upgrading an existing app requires no manual step:
  the first dev boot regenerates manifests and ensures the ignore entry.

## [0.2.34] - 2026-07-02

### Added
- Optional AST-based symbol extraction: add `gem "mini_racer"` to opt in. Definitions and usages are derived from a real JS/JSX AST (Acorn + acorn-jsx) instead of regex when available, fixing false positives where an unrelated word (e.g. plain JSX text like "Show More") is indistinguishable from a real component reference to a regex scanner. Falls back to regex extraction per-file on any parse failure, always with a line-numbered warning. No behavior change for apps that don't add `mini_racer`.
- New `config.isolated_app_dirs` option. A listed controller dir's own manifest is generated as usual, but its files/symbols are never inferred as a dependency of any *other* controller's manifest. Without the AST extraction above (i.e. no `mini_racer`), symbol usage detection is regex-based, so a generic component name can collide with an unrelated word appearing as plain JSX text elsewhere (e.g. a `Show` component vs. a "Show More" button label in a completely different controller) and get wrongly inlined into every other bundle. Use this as a manual, always-available fallback for self-contained dirs — e.g. a page-builder tool bundling its own vendored library — that should never leak into other pages, whether or not `mini_racer` is installed.

## [0.2.33] - 2026-07-01

### Fixed
- `resolve_bundle_for_component`/`resolve_bundles_for_component(_direct)` (used by the `react_component` view helper) now pick up new controllers and components added while a development server is still running. Their `component_maps` cache is keyed only on config values, not on what's on disk, so once anything primed the cache (any earlier `react_component` call in the process), a controller dir or component added afterward was invisible until the process restarted — `react_component` would silently render with no bundle injected. The file watcher now invalidates this cache on every file change, the same way it already invalidates the scanner's per-file symbol cache.

## [0.2.32] - 2026-07-01

### Added
- Generation now removes AUTO-GENERATED manifests whose `ux/app/<controller>/` directory no longer exists (renamed or deleted). Previously these were left behind indefinitely, still `//= require`-ing source files that no longer existed — a landmine for `assets:precompile`. Pinned (non-AUTO-GENERATED) files are never touched, and dry-run mode only logs what would be removed.

### Changed
- `config.stdout_logging` now defaults to `false`. `Rails.logger` always receives ReactManifest's status lines regardless of this flag; `stdout_logging` only controls an *additional* direct print to the terminal. Many development setups already have `Rails.logger` broadcast to stdout (`RAILS_LOG_TO_STDOUT`, Docker, `bin/dev`/Foreman), so the previous default of `true` printed every "File change detected" / "N manifest(s) written" line twice. Set `config.stdout_logging = true` explicitly if your `Rails.logger` does not already surface output in your terminal.

## [0.2.31] - 2026-07-01

### Fixed
- Controller manifests no longer pull in an unrelated bundle's files just because a component name collides (e.g. a generic `Show` component defined in two different `ux/app/*` dirs). A bundle now always satisfies a symbol from its own files first, instead of attributing it to whichever bundle happened to define that name first.
- `react_component` no longer silently stops auto-injecting a component's bundle for the rest of the request after `react_bundle_tag` has rendered once. Previously, calling `react_component` for a component in an unrelated bundle (not the current controller's own bundle, e.g. from a haml/erb view mixing controller-based and component-based rendering) would render with no script tag at all if `react_bundle_tag` had already run earlier in the same request.

### Removed
- The gem version is no longer embedded in the `AUTO-GENERATED` manifest header. Previously every manifest's content digest changed on every gem upgrade, forcing a full regeneration of all `ux_*.js` files for no functional reason.

## [0.2.28] - 2026-05-11

### Fixed
- Boot generation now runs after app initializers (`config/initializers/`) have loaded, so the generator always uses the fully-configured `ux_root` and related settings. Previously the initializer ran during the Railtie phase (before `config/initializers/`), causing it to silently generate against default paths and produce unchanged manifests.

## [0.2.27] - 2026-05-11

### Fixed
- Boot-time manifest generation now runs on every development restart rather than only when manifests are completely absent. Shared files added between restarts (e.g. via `git merge`) are picked up immediately without needing to touch a watched file or manually run `rails react_manifest:generate`.

### Changed
- Removed dead selective-shared-loading infrastructure from `Generator`. The scanner is no longer called from `Generator#run!` (it remains available for `react_manifest:analyze`). `build_controller_context` no longer computes `shared_requires`, `shared_lib_requires`, or their four supporting private methods (`shared_require_path_set`, `shared_lib_require_paths`, `build_shared_dependency_map`, `expand_shared_requires`). Controller manifests continue to load all shared files via `ux_shared` plus cross-bundle and external dependencies.

## [0.2.26] - 2026-04-22

### Fixed
- Resolved RuboCop offenses introduced in v0.2.25: removed useless `lib_reqs`/`shared_reqs` assignments in `build_controller`, corrected multiline method-call indentation in `build_shared`, and wrapped long line in `run!`.

### Changed
- Release preflight script now runs the full RSpec suite and RuboCop before allowing a tag/push, blocking the release if either fails.

## [0.2.25] - 2026-04-22

### Fixed
- Restored `build_shared` method in `Generator` that had been deleted, causing `ux_shared.js` to never be written. This was the root cause of a major regression where shared components (`components/`, `hooks/`, `lib/`) were absent from the asset pipeline on clean deploys.
- `Generator#run!` now generates `ux_shared.js` (all files from shared dirs) as the first manifest before controller manifests.
- Controller manifests (`ux_<controller>.js`) no longer inline shared-dir files (`lib_reqs`, `shared_reqs`). Shared files live exclusively in `ux_shared.js`, restoring the original lean-manifest architecture and preventing duplication.
- `resolve_bundles` view helper no longer silently drops the shared bundle when `ux_shared.js` is absent; the file is now always generated so the helper correctly returns `[ux_shared, ux_<controller>]` for every page.

### Added
- Release preflight hook (`.github/hooks/release-preflight.json` + script) that blocks `git tag`/`git push` commands when `VERSION`, `CHANGELOG.md`, and `Gemfile.lock` are out of sync.
- Session-start hook (`.github/hooks/release-session.json`) that injects the release protocol into the Copilot agent context.

## [0.2.24] - 2026-04-22

### Fixed
- Controller manifests now inline files from bundles listed in `always_include` (for example `ux_main`), so runtime symbol availability no longer depends on cross-bundle script execution order in production.
- Scanner analysis no longer emits warnings for ux/app file naming convention mismatches, reducing noise for apps that intentionally use custom filename patterns.

### Changed
- Updated `Gemfile.lock` to keep lockfile state aligned with the released codebase.

## [0.2.23] - 2026-04-21

### Fixed
- `react_component` now emits only `ux_shared` plus the direct owning bundle for the requested component symbol, instead of also emitting transitive controller manifests as separate script tags. This prevents unnecessary network requests for additional `ux_*.js` manifests while preserving dependency loading through generated manifest `require` directives.
- Generator now skips `external_roots` and `external_providers` entries that resolve to files already included in `ux_shared`, preventing duplicate runtime declarations from overlapping shared/external includes.
- View helper bundle deduplication now canonicalizes bundle names (e.g. `ux_shared` vs `ux_manifests/ux_shared`) to avoid re-emitting equivalent script tags.
- Controller manifests now include scanner-detected shared dependencies after `ux_shared` removal, including transitive shared dependencies needed by shared components (for example `DataTable` -> `SortHeader`).
- Shared `ux/lib` utility files are now included in controller manifests, restoring runtime availability for global helper functions such as `formatDate` and `formatCurrency`.

## [0.2.10] - 2026-04-16

### Fixed
- `ApplicationMigrator` now removes only `ux`-classified directives and preserves non-UX requires in `application*.js`, preventing accidental removal of root-level assets such as `mini-search`.
- Re-running migration/setup no longer duplicates the managed header comment block in `application*.js`.

### Added
- Regression coverage for preserving unknown non-UX requires during migration.
- Regression coverage for idempotent managed-header behavior on repeated migration runs.
- Dummy app root-level fixture assets (`axios.min.js`, `mini-search.js`) and corresponding requires in `application.js` / `application_dev.js` to verify setup behavior before release.

## [0.2.9] - 2026-04-15

### Added
- `rails react_manifest:setup` — one-command onboarding that patches `application.js`, `manifest.js`, and layout files, then generates initial bundles. Supports `DRY_RUN=1` preview mode.
- `ReactManifest::LayoutPatcher` — automatically inserts `react_bundle_tag` into ERB, HAML, and Slim layouts after `javascript_include_tag`, with `</head>` fallback. Preserves indentation and is idempotent.
- `ReactManifest::SprocketsManifestPatcher` — adds the `//= link_tree ../javascripts/ux_manifests .js` directive to `app/assets/config/manifest.js` so Sprockets 4 compiles the generated bundles.

### Fixed
- Removed a `Proc` from `config.assets.precompile` that crashed Sprockets 4.2+ with `NoMethodError: undefined method 'start_with?' for an instance of Proc`. The `link_tree` directive (handled by `SprocketsManifestPatcher`) is the correct mechanism.

### Changed
- `react_manifest:generate` now warns if the Sprockets manifest has not yet been patched.
- README rewritten with a streamlined Quick Start centred on `react_manifest:setup`.
- Confirmed full production asset pipeline compatibility: all ux bundles compile, minify, digest, and gzip correctly via `assets:precompile` with any standard JS compressor (uglifier/mini_racer, terser, libv8).

## [0.2.8] - 2026-04-15

### Fixed
- Prevented duplicate bundle conflicts by removing legacy root `ux_*.js` files when an equivalent generated manifest already exists in the manifest directory.
- Ensured generated manifest directory has deterministic Sprockets precedence by prepending it in assets paths.

### Changed
- Added regression coverage for duplicate legacy-manifest cleanup behavior.

## [0.2.7] - 2026-04-15

### Added
- Generated manifests now live in a dedicated folder (`app/assets/javascripts/ux_manifests` by default) to keep `app/assets/javascripts` tidy.
- Automatic migration of legacy `ux_*.js` files from `output_dir` root into the manifest folder during generation.

### Changed
- Added `config.manifest_subdir` (default: `ux_manifests`) for explicit control over generated manifest placement.
- `react_manifest:clean` now removes auto-generated manifests from both the dedicated manifest folder and legacy root location.
- README and inline configuration docs updated to explain the clean manifest directory behavior.

## [0.2.6] - 2026-04-15

### Fixed
- Resolved Railtie boot error caused by calling private class method `missing_manifest_bundles` with an explicit receiver.
- Development server boot no longer raises `private method missing_manifest_bundles called for ReactManifest::Railtie:Class`.

## [0.2.5] - 2026-04-15

### Fixed
- Updated root `Gemfile.lock` to stay in sync with gemspec version changes, fixing frozen Bundler install failures in the release workflow.

### Changed
- Follow-up release from `0.2.4` to ensure GitHub Release trusted publishing can complete successfully.

## [0.2.4] - 2026-04-15

### Changed
- Clarified configuration semantics for `ignore`, `exclude_paths`, `dry_run`, `verbose`, and `stdout_logging` in inline code comments.
- Updated README with clearer guidance on default configuration usage and explicit behavior notes for `ignore` vs `exclude_paths`.
- Documented that scanning scope is limited to `ux_root` and that `exclude_paths` is path-segment based (not `application.js` include based).

## [0.2.3] - 2026-04-15

### Added
- Compatibility entrypoint (`lib/react-manifest-rails.rb`) so default Bundler auto-require reliably loads the Railtie and rake tasks.
- Development boot-time sync that generates missing `ux_*.js` manifests once on server start.
- Configurable stdout logging with `config.stdout_logging` for visible generation events in development.

### Changed
- Streamlined README into a concise development-first quickstart with direct troubleshooting for missing tasks and watcher behavior.
- Improved `react_manifest:generate` diagnostics when `ux_root` is missing or no controller bundles are detected.
- Watcher and boot-time generation now emit clearer runtime status lines for easier debugging.

## [0.2.2] - 2026-04-15

### Changed
- Lowered required Ruby version from >= 3.2.0 to >= 3.0.0

## [0.1.0] - 2026-04-13

### Added
- Initial release of react-manifest-rails gem
- Zero-touch Sprockets manifest generation for react-rails applications
- Automatic per-controller bundle generation (`ux_*.js` manifests)
- File watcher for development that regenerates bundles on file changes
- Smart `react_bundle_tag` view helper for automatic bundle selection
- Intelligent bundle resolution for namespaced controllers
- Automatic shared bundle generation for common dependencies
- Configuration system with sensible defaults
- Integration with Rails' `assets:precompile` for production deployments
- Comprehensive README with setup instructions and usage examples
- Bundle size warnings to catch oversized bundles
- Support for Rails 6.1+ and Ruby 2.6+
