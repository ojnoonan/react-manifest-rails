require_relative "lib/react_manifest/version"

Gem::Specification.new do |spec|
  spec.name        = "react-manifest-rails"
  spec.version     = ReactManifest::VERSION
  spec.authors     = ["Oliver Noonan"]
  spec.email       = [""]
  spec.summary     = "Zero-touch Sprockets manifest generation for react-rails apps"
  spec.description = <<~DESC
    react-manifest-rails automatically generates per-controller Sprockets manifest
    files for Rails applications using react-rails + Sprockets. It eliminates the
    monolithic application.js by creating lean, controller-specific ux_*.js bundles,
    watches for file changes in development, and provides a smart react_bundle_tag
    view helper that auto-selects the correct bundle per controller.
  DESC
  spec.homepage      = "https://github.com/olivernoonan/react-manifest-rails"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*",
    "tasks/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "railties", ">= 7.0", "< 9"

  # Development dependencies
  spec.add_development_dependency "rails", ">= 7.0", "< 9"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec",       "~> 3.12"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "sprockets-rails"
  # listen is a soft runtime dependency (file watching in development).
  # The gem gracefully degrades without it; add to your app's Gemfile:
  #   gem "listen", "~> 3.0", group: :development
  spec.add_development_dependency "listen", "~> 3.0"
end
