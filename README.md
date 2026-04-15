# react-manifest-rails

Generate per-controller Sprockets manifests for React code in Rails.

This gem creates `ux_*.js` bundles and includes them with `react_bundle_tag`.

## Quick Start (Development)

1. Add gems:

```ruby
# Gemfile
gem "react-manifest-rails"

group :development do
  gem "listen", "~> 3.0"
end
```

2. Install:

```bash
bundle install
```

3. Add initializer:

```ruby
# config/initializers/react_manifest.rb
require "react_manifest"

ReactManifest.configure do |config|
  config.ux_root = "app/assets/javascripts/ux"
  config.app_dir = "app"
  config.output_dir = "app/assets/javascripts"
  config.shared_bundle = "ux_shared"
  config.always_include = []
  config.ignore = []
  config.exclude_paths = ["react", "react_dev", "vendor"]
  config.size_threshold_kb = 500
  config.dry_run = false
  config.verbose = false
  config.stdout_logging = true
end
```

4. Put React files under:

```text
app/assets/javascripts/ux/
  app/
    users/
      users_index.jsx
  components/
    nav.jsx
```

5. Include bundles in your layout:

```erb
<%= react_bundle_tag defer: true %>
```

6. Start server:

```bash
bundle exec rails s
```

In development:
- If expected `ux_*.js` files are missing, the gem generates them once on boot.
- If `listen` is installed, file changes regenerate manifests automatically.
- If `listen` is missing, run `bundle exec rails react_manifest:generate` manually.
- Set `config.stdout_logging = false` to silence ReactManifest console lines while keeping Rails logger output.

## What Gets Generated

- `ux_shared.js`: shared files outside `ux/app/`
- `ux_<controller>.js`: one bundle per directory under `ux/app/`

Example:
- `ux/app/users/...` -> `ux_users.js`
- `ux/app/admin/...` -> `ux_admin.js`

## Commands

- Generate manifests now:

```bash
bundle exec rails react_manifest:generate
```

- Watch in foreground (debugging only; not required in normal dev):

```bash
bundle exec rails react_manifest:watch
```

- Print bundle size report:

```bash
bundle exec rails react_manifest:report
```

## Troubleshooting

### `react_manifest:generate` is not recognized

Run:

```bash
bundle exec rails -T | grep react_manifest
```

If nothing appears:
- Confirm the gem is in `Gemfile` and installed (`bundle show react-manifest-rails`).
- Ensure the gem is not disabled with `require: false`.
- Restart Spring/server (`bin/spring stop`, then re-run command).

### Server starts but nothing happens

Check these in order:
- `app/assets/javascripts/ux` exists.
- Your controller files are under `ux/app/<controller>/`.
- Your layout includes `<%= react_bundle_tag %>`.
- Run `bundle exec rails react_manifest:generate` once and check for generated `ux_*.js` in `app/assets/javascripts`.

### Auto-watch in dev does not run

- Ensure `listen` is in the development group.
- Restart the Rails server after adding `listen`.
- If you choose not to install `listen`, manual generation is the supported fallback.

## Compatibility

- Ruby: 3.2+
- Rails/Railties: 7.x to 8.x
- Asset pipeline: Sprockets

## License

MIT
