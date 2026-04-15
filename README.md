# react-manifest-rails

**Zero-touch Sprockets manifest generation for react-rails apps**

A Rails gem that automatically generates lean, controller-specific JavaScript bundles for applications using `react-rails` and Sprockets, eliminating the need for monolithic `application.js` files.

## Features

- **Automatic bundle generation**: Creates per-controller `ux_*.js` manifests on-demand
- **Smart file watching**: Automatically regenerates bundles when files change in development
- **Intelligent bundle resolution**: The `react_bundle_tag` view helper automatically selects the correct bundles for each controller
- **Namespace-aware**: Handles nested controllers and namespaces gracefully (e.g., `admin/users` → `ux_admin_users`)
- **Shared bundles**: Automatically extracts shared dependencies into a `ux_shared` bundle
- **Always-include bundles**: Configure bundles that should be loaded on every page
- **Production-ready**: Integrates seamlessly with `assets:precompile` for CI/production deployments
- **Zero configuration**: Works out-of-the-box with sensible defaults for standard Rails projects

## Advantages

### 1. Smaller Bundle Sizes
Instead of a single monolithic `application.js` that loads all React components for the entire app, each controller gets its own lean bundle containing only the components it needs. This means:
- **Faster page loads**: Users only download what they need
- **Better caching**: Components unchanged on their page won't bust the cache
- **Reduced bandwidth**: Particularly beneficial for mobile users

### 2. Simplified Development
- **Automatic regeneration**: Changes to component files are automatically bundled—no manual build steps
- **No configuration needed**: Works with standard Rails directory structures immediately
- **Easy integration**: Drop the gem in and it works with your existing `react-rails` setup

### 3. Production Reliability
- **CI/CD friendly**: Integrates with `assets:precompile` for automated deployments
- **Deterministic builds**: Consistent bundle generation across environments
- **Safety checks**: Warns about oversized bundles to catch potential issues

### 4. Developer Experience
- **Per-controller organization**: Bundle structure mirrors your Rails controller layout
- **Smart bundle selection**: View helper automatically picks the right bundles—no manual tag management
- **Clear visibility**: Built-in reporter shows exactly what's in each bundle

## Installation

Add the gem to your `Gemfile`:

```ruby
gem 'react-manifest-rails'
```

Then run:

```bash
bundle install
```

## Setup

### 1. Create your UX directory structure

By default, the gem expects your React components to live in `app/assets/javascripts/ux/`. You should organize it like this:

```
app/assets/javascripts/ux/
├── app/                          # Per-controller components (becomes ux_*.js bundles)
│   ├── users/
│   │   ├── UserCard.jsx
│   │   └── UserList.jsx
│   ├── products/
│   │   └── ProductGrid.jsx
│   └── dashboard/
│       └── Dashboard.jsx
├── shared/                        # Shared utilities (becomes ux_shared)
│   ├── api.js
│   └── utils.js
└── components/                    # Global components (becomes ux_shared)
    └── Navigation.jsx
```

### 2. Configure the gem (Optional)

Create an initializer at `config/initializers/react_manifest.rb`:

```ruby
ReactManifest.configure do |config|
  # Where your UX root lives (default: "app/assets/javascripts/ux")
  config.ux_root = "app/assets/javascripts/ux"

  # Subdir within ux_root containing per-controller components (default: "app")
  config.app_dir = "app"

  # Where generated manifests are written (default: "app/assets/javascripts")
  config.output_dir = "app/assets/javascripts"

  # Name of the shared bundle (default: "ux_shared")
  config.shared_bundle = "ux_shared"

  # Bundles to always include on every page (default: [])
  # config.always_include = ["ux_main"]

  # Directories within app_dir to ignore (default: [])
  # config.ignore = ["internal_tools"]

  # Warn if any bundle exceeds this size in KB (default: 500, 0 to disable)
  config.size_threshold_kb = 500
end
```

### 3. Use the view helper

In your layout template (`app/views/layouts/application.html.erb` or similar):

```erb
<head>
  <%= javascript_include_tag "application" %>
  <%= react_bundle_tag defer: true %>
</head>
```

The `react_bundle_tag` helper automatically:
1. Includes the shared bundle (`ux_shared`)
2. Includes any bundles in `config.always_include`
3. Includes the controller-specific bundle (e.g., `ux_users` for UsersController)
4. Returns an empty string gracefully if there's no matching bundle

## How It Works

### Bundle Generation

The gem scans your `app/assets/javascripts/ux/` directory and generates Sprockets manifests:

- **Controller-specific bundles**: Each directory under `ux/app/` becomes a bundle
  - `ux/app/users/` → `ux_users.js`
  - `ux/app/admin/reports/` → `ux_admin_reports.js`

- **Shared bundle**: Everything outside `ux/app/` (e.g., `shared/`, `components/`) automatically goes into `ux_shared.js`

- **Dependency tracking**: The gem analyzes dependencies to prevent duplication across bundles

### Development

In development, a file watcher automatically:
- Detects changes to component files
- Regenerates affected bundles
- Updates manifests in real-time

### Production

The gem integrates with Rails' `assets:precompile` task:

```bash
rails assets:precompile
```

This ensures all bundles are generated before deployment.

## View Helper Usage

### Basic usage

```erb
<%= react_bundle_tag %>
```

### With HTML options

```erb
<%= react_bundle_tag defer: true, async: true %>
```

### Automatic resolution

The helper automatically resolves bundles based on `controller_path`:

| Controller | Resolved Bundles |
|-----------|------------------|
| UsersController | ux_shared + ux_users |
| Admin::ReportsController | ux_shared + ux_admin_reports (or ux_admin if not found) |
| Pages::LandingController | ux_shared + ux_pages_landing (or ux_pages, or ux_landing) |

## Rake Tasks

### Generate bundles (one-time)

```bash
rails react_manifest:generate
```

### Watch for changes (development)

```bash
rails react_manifest:watch
```

### Show bundle contents

```bash
rails react_manifest:report
```

## Configuration Reference

| Option | Default | Description |
|--------|---------|-------------|
| `ux_root` | `"app/assets/javascripts/ux"` | Root directory of your React components |
| `app_dir` | `"app"` | Subdirectory of `ux_root` for per-controller components |
| `output_dir` | `"app/assets/javascripts"` | Where generated manifests are written |
| `shared_bundle` | `"ux_shared"` | Name of the shared bundle |
| `always_include` | `[]` | Array of bundle names to load on every page |
| `ignore` | `[]` | Directories to skip during scanning |
| `exclude_paths` | `["react", "react_dev", "vendor"]` | Top-level directories to exclude |
| `size_threshold_kb` | `500` | Warn if a bundle exceeds this size (0 = disabled) |
| `dry_run` | `false` | Print what would change without writing files |
| `verbose` | `false` | Enable extra logging |

## Troubleshooting

### Bundle not being generated
- Check that your components are in the correct directory structure (`app/assets/javascripts/ux/app/...`)
- Run `rails react_manifest:report` to see what bundles were detected
- Check Rails logs for any file watcher errors

### Components not loading
- Verify `react_bundle_tag` is in your layout
- Check that the bundle name matches your controller path
- Make sure components are in the `ux/` directory, not elsewhere

### Size warnings
- The gem warns when bundles exceed 500KB
- Consider splitting large bundles into smaller, more focused ones
- Adjust `config.size_threshold_kb` in your initializer if needed

## TypeScript / Custom Extensions

By default the gem scans `*.js` and `*.jsx` files. To add TypeScript support:

```ruby
ReactManifest.configure do |config|
  config.extensions = %w[js jsx ts tsx]
end
```

This affects file scanning, manifest generation, and the development file watcher.

## File Watching (`listen` gem)

The development file watcher requires the `listen` gem, which is **not** a hard dependency. If `listen` is absent the watcher is silently disabled and you must regenerate manifests manually.

To enable watching, add `listen` to the development group in your app's `Gemfile`:

```ruby
gem "listen", "~> 3.0", group: :development
```

> **Note:** Changes to `config/initializers/react_manifest.rb` are not picked up by the watcher — you must restart the server after editing the initializer.

## Migrating an Existing `application.js`

If you are adding this gem to an app that already has a monolithic `application.js`, use the built-in migration tools:

**Step 1 — Analyse what's there:**

```bash
rails react_manifest:analyze
```

This classifies each `//= require` line as `:vendor` (keep), `:ux_code` (remove), or `:unknown` (review manually). No files are modified.

**Step 2 — Preview changes:**

```bash
REACT_MANIFEST_DRY_RUN=1 rails react_manifest:migrate_application
```

**Step 3 — Apply changes:**

```bash
rails react_manifest:migrate_application
```

A `.bak` backup is created next to each modified file before any write.

**Step 4 — Generate bundles and verify:**

```bash
rails react_manifest:generate
rails assets:precompile  # or just start the dev server
```

**Rolling back:** Simply restore the `.bak` file and remove the generated `ux_*.js` manifests.

## Troubleshooting

### Bundle not being generated
- Verify components live under `ux/app/<controller>/` (not directly under `ux/`)
- Run `rails react_manifest:report` to see detected bundles
- Check Rails logs for file watcher errors

### Components not loading
- Confirm `react_bundle_tag` is present in your layout
- Check that the bundle name matches your controller path
- Run `rails react_manifest:generate` to force regeneration

### Bundle appears more than once in HTML output
- A bundle name in `config.always_include` that is also the controller bundle will be deduplicated automatically. Check whether both the shared bundle name and a specific bundle are listed in `always_include`.

### Watcher stops responding
- This is usually resolved by restarting the development server
- Ensure the `listen` gem is installed (see above)

### Generator crashes on first run
- Check that the process has write permission to `config.output_dir`
- Verify `config.ux_root` exists; the generator is a no-op if the directory is missing

### Size warnings
- The gem warns when bundles exceed `config.size_threshold_kb` (default 500 KB)
- Consider splitting large controller directories or moving shared code into the shared bundle
- Adjust the threshold: `config.size_threshold_kb = 1000`

## Performance

| Scenario | Typical time |
|----------|-------------|
| Initial generation (small project, ~20 controllers) | < 1 s |
| Initial generation (large project, ~100 controllers) | 2–5 s |
| Watcher debounce (regeneration after file change) | ~300 ms |
| Memory overhead (symbol index, large project) | < 10 MB |

Scanning is purely regex-based — no Node.js or transpilation step required.

## Compatibility

| Dependency | Supported versions |
|------------|-------------------|
| Ruby | 3.2, 3.3 |
| Rails / Railties | 6.1 – 8.x |
| Sprockets | 3.x, 4.x |
| listen (optional) | ~> 3.0 |

> **Pre-1.0 notice:** The public API (configuration keys, rake task names, view helper signature) may change in minor versions until 1.0 is released. Pin to a patch version if stability is critical: `gem "react-manifest-rails", "~> 0.1.0"`.

## Requirements

- Ruby >= 3.2
- Rails >= 6.1
- Sprockets
- react-rails

## License

MIT License. See LICENSE for details.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olivernoonan/react-manifest-rails.
