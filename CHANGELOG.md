# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
