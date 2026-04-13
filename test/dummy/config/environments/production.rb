Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.assets.compile = false
  config.assets.digest = true
  config.log_level = :info
  config.log_tags = [:request_id]
  config.force_ssl = true
end
