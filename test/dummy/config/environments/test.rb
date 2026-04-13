Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = false
  config.assets.debug = false
  config.assets.quiet = true
end
