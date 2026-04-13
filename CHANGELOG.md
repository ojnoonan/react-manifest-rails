# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
