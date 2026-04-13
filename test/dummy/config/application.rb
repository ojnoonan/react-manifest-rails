require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.0

    config.assets.enabled = true
    config.assets.version = "1.0"

    # Precompile per-controller ux bundles
    config.assets.precompile += Dir["app/assets/javascripts/ux_*.js"].map { |f| File.basename(f) }
  end
end
