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
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "tasks/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "railties",  ">= 6.1"
  spec.add_dependency "listen",    "~> 3.0"

  # Development dependencies
  spec.add_development_dependency "rspec",       "~> 3.12"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rails",       ">= 6.1"
  spec.add_development_dependency "sprockets-rails"
  spec.add_development_dependency "rake"
end
