# react-manifest-rails

Generate per-controller Sprockets manifests for React code in Rails.

Instead of one monolithic `application.js`, each controller gets a lean `ux_<controller>.js` bundle that only loads what it needs. Shared components, hooks, and libraries are automatically bundled into a single `ux_shared.js` included on every page.

## Quick Start

### 1. Add to Gemfile

```ruby
gem "react-manifest-rails"

group :development do
  gem "listen", "~> 3.0"  # optional — enables auto-regeneration on file change
end
```

```bash
bundle install
```

### 2. Add initializer

```ruby
# config/initializers/react_manifest.rb
ReactManifest.configure do |config|
  # All defaults shown — only override what you need to change.
  config.ux_root    = "app/assets/javascripts/ux"
  config.app_dir    = "app"
  config.output_dir = "app/assets/javascripts"
end
```

### 3. Run setup

```bash
bundle exec rails react_manifest:setup
```

This one command:
- Patches `application.js` to remove globally-required React files (they'll be per-controller instead)
- Patches `app/assets/config/manifest.js` to add the `link_tree` directive Sprockets needs to compile the bundles
- Patches your layout(s) to insert `react_bundle_tag`
- Generates the initial `ux_*.js` manifests

Preview changes without writing anything:

```bash
DRY_RUN=1 bundle exec rails react_manifest:setup
```

### 4. Organise your React files

```text
app/assets/javascripts/ux/
  app/
    users/          → compiled into ux_users.js
      users_index.jsx
    dashboard/      → compiled into ux_dashboard.js
      dashboard.jsx
  components/       → compiled into ux_shared.js (included on every page)
    nav.jsx
    button.jsx
  hooks/            → also goes into ux_shared.js
    use_modal.js
  lib/              → also goes into ux_shared.js
    helpers.js
```

### 5. Start the server

```bash
bundle exec rails s
```

In development:
- Missing `ux_*.js` files are generated automatically on boot.
- If `listen` is installed, saving any file under `ux/` regenerates affected manifests instantly.
- Without `listen`, run `bundle exec rails react_manifest:generate` after adding files.

## How Bundle Inclusion Works

Generation is **directory-based** — deterministic and conservative by design.

- `ux_shared.js`: every file from directories outside `ux/app/` (i.e. `components/`, `hooks/`, `lib/`, etc.)
- `ux_<controller>.js`: every file under `ux/app/<controller>/`, plus transitive controller dependencies inferred from component usage across `ux/app/*`

`ux_shared.js` is loaded as a separate script by `react_bundle_tag` and `react_component` helpers. It is intentionally not inlined into every `ux_<controller>.js` manifest to avoid duplicating shared code across controller bundles.

Namespace fallback for nested controllers: `admin/reports/summary` tries `ux_admin_reports_summary`, then `ux_admin_reports`, then `ux_admin`, then `ux_summary`. The most specific match wins.

When using `react-rails`, `react_component("ComponentName")` is also component-aware: the helper infers the matching controller bundle from the component symbol and includes it at render time. This provides a fallback when controller naming and bundle naming do not align perfectly.

The gem's scanner uses regex to detect which shared symbols are referenced in each controller directory (for the `react_manifest:analyze` report). Generation itself stays directory-based to avoid brittle runtime misses from dynamic component references.

## What Gets Generated

```
app/assets/javascripts/ux_manifests/   ← generated; do not edit
  ux_shared.js
  ux_users.js
  ux_dashboard.js
  ...
```

Files carry an `AUTO-GENERATED` header. Any file without it is never overwritten — you can pin a manifest by removing the header.

Writes are atomic (temp file + rename) and idempotent (SHA-256 comparison skips unchanged files).

If a `ux/app/<controller>/` directory is renamed or deleted, its manifest is removed automatically on the next generation (dev file watcher, boot, or `rails react_manifest:generate`) — pinned files are never removed this way.

## Asset Compilation & Minification

The generated files are standard Sprockets manifests — `//= require` directives only. Sprockets processes them identically to `application.js`:

- **Development**: concatenated and served from memory.
- **Production** (`assets:precompile`): concatenated, minified (with whatever JS compressor your app uses — `uglifier`/`mini_racer`, `terser`, libv8, etc.), digested, and gzipped.

The gem hooks into `assets:precompile` as a prerequisite, so manifest generation always runs before Sprockets begins compiling.

## Configuration

```ruby
ReactManifest.configure do |config|
  config.ux_root          = "app/assets/javascripts/ux"
  config.app_dir          = "app"          # subdirectory of ux_root containing per-controller dirs
  config.output_dir       = "app/assets/javascripts"
  config.manifest_subdir  = "ux_manifests" # subdirectory of output_dir for generated files
  config.shared_bundle    = "ux_shared"
  config.extensions       = %w[js jsx]     # add ts tsx for TypeScript
  config.always_include   = []             # extra shared files always added to every bundle
  config.ignore           = []             # controller dir names to skip entirely
  config.isolated_app_dirs = []            # controller dir names that must never leak into other bundles
  config.exclude_paths    = ["react", "react_dev", "vendor"]  # path segments to exclude
  config.size_threshold_kb = 500           # warn if a bundle exceeds this
  config.dry_run          = false          # never write; only print what would change
  config.verbose          = false          # extra diagnostic detail
  config.stdout_logging   = false          # also print status lines directly to stdout (see note below)
end
```

### Key option notes

- **`ignore`**: skips entire controller dirs under `ux/app/`. `ignore = ["admin"]` excludes `ux/app/admin/`.
- **`isolated_app_dirs`**: a controller dir's own `ux_<name>.js` is generated as usual, but its files/symbols are never inferred as a dependency of any *other* controller. Without the optional AST engine below (i.e. no `mini_racer`), symbol usage detection is regex-based, so a generic component name can collide with an unrelated word appearing as plain JSX text elsewhere (e.g. a `Show` component vs. a "Show More" button label in a different controller) and get wrongly inlined everywhere. Use this as a manual, always-available fallback for self-contained dirs — e.g. a page-builder tool bundling its own vendored library — that should never leak into other pages, whether or not `mini_racer` is installed. `isolated_app_dirs = ["rvb"]` isolates `ux/app/rvb/`.
- **`exclude_paths`**: excludes files whose path contains any listed segment. Not based on `application.js`.
- **`dry_run`**: also honoured by `DRY_RUN=1` environment variable at runtime.
- **`extensions`**: add `ts` and `tsx` to enable TypeScript source detection.
- **`external_roots` / `external_providers`**: do not point these at files already inside shared `ux/` dirs (`components/`, `hooks/`, `lib/`, etc.). The generator now skips those overlaps to prevent duplicate declarations in browser runtime.
- **`stdout_logging`**: `Rails.logger` always receives status lines regardless of this flag. Turn this on only if your `Rails.logger` does *not* already print to your terminal in development — if it does (common with `RAILS_LOG_TO_STDOUT`, Docker, or `bin/dev`/Foreman setups), enabling this prints every line twice.
- **AST-based symbol extraction**: add `gem "mini_racer"` to your Gemfile to opt in. When present, definitions and usages are derived from a real JS/JSX AST (Acorn) instead of regex, which fixes false positives like a `Show` component colliding with unrelated text such as a "Show More" button label. Falls back to regex extraction per-file on any parse failure (always logged via `Rails.logger.warn` with file/line/column when available) — generation never breaks because of this. Without `mini_racer`, behavior is unchanged from today.

## Commands

```bash
# First-time setup (patches application.js, manifest.js, layouts; generates manifests)
bundle exec rails react_manifest:setup

# Regenerate all manifests
bundle exec rails react_manifest:generate

# Preview any command without writing
DRY_RUN=1 bundle exec rails react_manifest:setup
DRY_RUN=1 bundle exec rails react_manifest:generate

# Analyse which shared symbols are used per controller
bundle exec rails react_manifest:analyze

# Print bundle size report
bundle exec rails react_manifest:report

# Watch for changes in foreground (debugging only — dev server already does this)
bundle exec rails react_manifest:watch

# Remove all generated manifests
bundle exec rails react_manifest:clean
```

## Releasing

The publish workflow runs on tag pushes (`v*`), not on branch pushes.

1. Bump `ReactManifest::VERSION` in `lib/react_manifest/version.rb`.
2. Run `bundle install` to refresh the local path spec version in `Gemfile.lock`.
3. Commit and push to `main`/`master`.
4. Create and push a matching annotated tag:

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

This tag push triggers `.github/workflows/release.yml`, which runs tests, creates a GitHub Release, and publishes to RubyGems.

## Troubleshooting

### `AssetNotPrecompiledError` for `ux_*.js`

Sprockets 4 requires an explicit `link_tree` directive to compile files from non-standard paths. Run setup (or manually add the directive):

```bash
bundle exec rails react_manifest:setup
```

This adds `//= link_tree ../javascripts/ux_manifests .js` to `app/assets/config/manifest.js`.

### `react_manifest` tasks not found

```bash
bundle exec rails -T | grep react_manifest
```

If nothing appears:
- Confirm the gem is in `Gemfile` and installed (`bundle show react-manifest-rails`).
- Ensure it is not loaded with `require: false`.
- Restart Spring: `bin/spring stop`.

### Server starts but no bundles are served

Check in order:
1. `app/assets/javascripts/ux/` exists.
2. Controller files are under `ux/app/<controller>/`.
3. Your layout includes `<%= react_bundle_tag %>`.
4. Run `bundle exec rails react_manifest:generate` and confirm files appear in `ux_manifests/`.
5. Confirm `app/assets/config/manifest.js` contains the `link_tree` directive (run setup again if missing).

### Auto-watch not running in development

- Add `listen` to the development group in your Gemfile and `bundle install`.
- Restart the Rails server.
- Without `listen`, run `react_manifest:generate` manually after making changes.

### `ComponentName is not defined` from `react_component`

If you see errors like `UserSignInForm is not defined` (often from `eval` inside `react-rails`), ensure your layout does **not** defer the bundle tag:

```erb
<%= react_bundle_tag %>
```

Using `defer: true` can cause `react_component` inline scripts to run before your `ux_*.js` bundles are executed.

### `Identifier '<Name>' has already been declared`

This usually means the same component/function is being loaded from two separate bundles.

Common cause: a file outside `ux/` (for example `app/assets/javascripts/components/navbar/*` loaded by `application.js`) references a symbol defined in `ux/app/<controller>/...`, while that controller bundle is also loaded via `react_bundle_tag`.

Recommended fix:
- Move globally reused symbols out of `ux/app/*` into a shared dir (`ux/components`, `ux/hooks`, `ux/lib`) so they are emitted once via `ux_shared.js`.
- Keep controller-specific symbols in `ux/app/*` and avoid importing/using them from non-ux global assets.

If you use `external_roots`, `react_manifest:analyze` and generation warnings will now flag this pattern explicitly.

## Compatibility

- Ruby: 3.2+
- Rails: 7.x – 8.x
- Asset pipeline: Sprockets 3 and 4
- JS compressors: uglifier / mini_racer, terser, libv8 / therubyracer — all work transparently

## License

MIT
