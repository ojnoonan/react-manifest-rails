# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Tests
bundle exec rake test                                           # full suite
bundle exec rake test TEST=test/react_manifest/generator_test.rb  # single file
bundle exec rake test:stress                                    # stress tests

# Linting
bundle exec rubocop --parallel

# Ruby version (managed via asdf)
asdf local ruby 3.3.3
bundle install
```

Coverage is written to `coverage/` via simplecov after every test run.

## Architecture

This is a Rails gem (`react-manifest-rails`) that auto-generates per-controller Sprockets manifest files for apps using `react-rails` + Sprockets. The core idea: instead of one monolithic `application.js`, each controller gets a lean `ux_<controller>.js` that only loads what it needs.

### Generated file layout (inside a host app)

```
app/assets/javascripts/ux/
├── app/              ← per-controller source (one subdir → one ux_<name>.js)
│   ├── users/
│   └── notifications/
├── components/       ← shared code → feeds ux_shared.js
├── hooks/
└── lib/
app/assets/javascripts/
├── ux_shared.js      ← AUTO-GENERATED: requires all shared files
├── ux_users.js       ← AUTO-GENERATED: requires ux_shared + users/ files
└── ux_notifications.js
```

### Pipeline

```
TreeClassifier → Scanner → Generator
                         ↘ DependencyMap (reporting only)
```

Both Scanner and Generator delegate all JS symbol work to `SymbolExtractor`.

1. **`TreeClassifier`** (`tree_classifier.rb`) — walks `ux_root` and produces two lists: `shared_dirs` (anything not under `app_dir`) and `controller_dirs` (immediate subdirs of `app_dir`). Uses `File.realpath` to follow symlinks.

2. **`Scanner`** (`scanner.rb`) — Phase 1: regex-indexes exported symbols from shared dirs into a `symbol_index` (`"PrimaryButton" → "ux/components/…"`). Phase 2: scans controller files for usages (JSX tags, hook calls, lib calls) and maps them to the shared files they reference. Delegates all symbol extraction to `SymbolExtractor`; calls `config.excluded_path?` for path filtering.

3. **`Generator`** (`generator.rb`) — builds all manifest content in memory first (`build_shared`, `build_controller`), then writes atomically (temp file + rename) so no partial state is left on failure. Skips files without the `AUTO-GENERATED` header (user-pinned). Idempotent via SHA-256 digest comparison. Delegates symbol extraction to `SymbolExtractor`; calls `config.excluded_path?` for path filtering.
   With `config.auto_shared` (default on), a controller-owned file used by any other
   bundle is promoted into `ux_shared` (transitively) so each file is emitted into
   exactly one bundle; `auto_shared = false` restores legacy cross-app inlining.

4. **`Configuration`** (`configuration.rb`) — single config object. Key options: `ux_root`, `app_dir`, `output_dir`, `extensions` (`%w[js jsx]` by default; add `ts tsx` for TypeScript), `shared_bundle`, `always_include`, `exclude_paths`, `dry_run`, `verbose`. Provides `excluded_path?(abs_path)` (shared predicate used by Scanner and Generator) and `cache_key` (hash over the six fields that affect component maps, used to auto-invalidate `@component_maps_cache` on mutation).

5. **`SymbolExtractor`** (`symbol_extractor.rb`) — `module_function` module with two methods: `extract_definitions(content)` returns all PascalCase/hook symbols defined in a JS/JSX string; `extract_usages(content)` returns all external symbols referenced (filters out locally-defined names and `JS_BUILTINS`). Single source of truth for all regex patterns and builtins. Called by Scanner, Generator, and `ReactManifest.resolve_bundles_for_component_direct`.

6. **`Watcher`** (`watcher.rb`) — wraps the `listen` gem (soft dependency; silently disabled if absent). Started by the Railtie in development. Uses `config.extensions_pattern` for the file filter regex.

7. **`ViewHelpers`** / **`ReactManifest.resolve_bundles`** (`lib/react_manifest.rb`) — `react_bundle_tag` in views calls `resolve_bundles(controller_path)`, which checks disk for matching `ux_*.js` files. Namespace fallback: `admin/reports/summary` tries `ux_admin_reports_summary`, `ux_admin_reports`, `ux_admin`, then `ux_summary` (leaf segment).

8. **`ApplicationAnalyzer` / `ApplicationMigrator`** — one-time tools for migrating an existing monolithic `application.js`. Analyzer classifies each `//= require` line; Migrator rewrites the file (with `.bak` at `chmod 0600`).

9. **`DependencyMap`** (`dependency_map.rb`) — read-only view over scan results. Maintains an inverted index for O(1) `controllers_using(file)` lookups. Used by `react_manifest:analyze`.

### Railtie hooks

- Starts `Watcher` in development if not already running.
- Includes `ViewHelpers` into `ActionView::Base`.
- Prepends `react_manifest:generate` as a prerequisite to `assets:precompile`.
- In development, also reconciles `.gitignore` (adds the manifest-dir ignore entry if
  missing) via `ReactManifest.reconcile_gitignore!` / `GitignorePatcher`. Dev-only;
  production never writes to the app tree at boot.

### Testing

Tests use a minimal FakeRails stub (defined in `test/test_helper.rb`) instead of loading the full Rails stack. Fixture files live in `test/fixtures/dummy/app/assets/javascripts/ux/`. Each test wraps examples in `with_temp_rails_root { }` which copies fixtures to a tmpdir and points `Rails.root` there.

The `ReactManifest` module (including `resolve_bundles` and `controller_candidates`) is redefined inline in `test_helper.rb` for isolation — the production version lives in `lib/react_manifest.rb`.

### Key constraints

- No AST parsing or Node.js — symbol detection is pure Ruby regex.
- The `listen` gem is a soft dependency; never make it required at runtime.
- Generated files carry an `AUTO-GENERATED` header; the generator never touches files without it.
- All manifest writes are atomic (tmp + rename). Content is built fully in memory before any I/O begins.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/ojnoonan/react-manifest-rails`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
