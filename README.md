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

## Requirements

- Ruby >= 2.6.0
- Rails >= 6.1
- Sprockets
- react-rails

## License

MIT License. See LICENSE for details.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olivernoonan/react-manifest-rails.
