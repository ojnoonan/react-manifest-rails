module ReactManifest
  # Provides the `react_bundle_tag` view helper, included in ActionView::Base.
  #
  # Usage in layouts:
  #   <%= react_bundle_tag %>
  #
  # Resolves which ux_*.js bundles to include based on controller_path:
  #   1. Always includes config.shared_bundle (e.g. "ux_shared")
  #   2. Always appends config.always_include (e.g. ["ux_main"])
  #   3. Appends "ux_<controller_path>" if that bundle file exists
  #   4. For namespaced controllers (admin/users): checks ux_admin_users, then ux_admin
  #   5. Returns "" for pure ERB/HAML pages with no matching bundle, or when
  #      called outside a controller context (mailers, engines, etc.)
  module ViewHelpers
    def react_bundle_tag(**html_options)
      # controller_path is not available in all view contexts (mailers, engines,
      # views rendered outside a request). Fall back gracefully rather than raising.
      ctrl = respond_to?(:controller_path, true) ? controller_path : nil
      return "".html_safe if ctrl.nil?

      bundles = ReactManifest.resolve_bundles(ctrl)
      return "".html_safe if bundles.empty?

      # Record emitted bundles so react_component doesn't re-emit them.
      emitted = (@_react_manifest_emitted_bundles ||= [])
      bundles.each { |b| emitted << b unless emitted.include?(b) }

      asset_names = bundles.map { |bundle| "#{bundle}.js" }
      javascript_include_tag(*asset_names, extname: false, **html_options)
    end

    # react-rails integration:
    # If a component-specific controller bundle can be inferred from the component
    # symbol, include that bundle at the call site before delegating to react-rails.
    # This avoids strict dependence on controller_path -> bundle naming alignment.
    def react_component(*args, **kwargs, &block)
      html = super

      component_name = args.first
      bundles = ReactManifest.resolve_bundles_for_component(component_name)
      return html if bundles.empty?

      emitted = (@_react_manifest_emitted_bundles ||= [])

      new_tags = bundles.filter_map do |bundle|
        next if emitted.include?(bundle)

        emitted << bundle
        javascript_include_tag("#{bundle}.js", extname: false)
      end

      return html if new_tags.empty?

      safe_join(new_tags + [html])
    end
  end
end
