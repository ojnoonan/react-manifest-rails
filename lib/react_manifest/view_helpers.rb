module ReactManifest
  # Provides the `react_bundle_tag` view helper, included in ActionView::Base.
  #
  # Usage in layouts:
  #   <%= react_bundle_tag %>
  #
  # Resolves which ux_*.js bundles to include based on controller_path:
  #   1. Appends config.always_include (e.g. ["ux_main"])
  #   2. Appends "ux_<controller_path>" if that bundle file exists
  #   3. For namespaced controllers (admin/users): checks ux_admin_users, then ux_admin
  #   4. Returns "" for pure ERB/HAML pages with no matching bundle, or when
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
      emitted = emitted_bundles
      fresh_bundles = bundles.reject { |b| emitted_bundle?(emitted, b) }
      return "".html_safe if fresh_bundles.empty?

      fresh_bundles.each { |b| emitted << b }

      asset_names = fresh_bundles.map { |bundle| "#{bundle}.js" }
      javascript_include_tag(*asset_names, extname: false, **html_options)
    end

    # react-rails integration:
    # If a component-specific controller bundle can be inferred from the component
    # symbol, include that bundle at the call site before delegating to react-rails.
    # This avoids strict dependence on controller_path -> bundle naming alignment.
    def react_component(*args, **kwargs, &block)
      html = super

      component_name = args.first
      bundles = ReactManifest.resolve_bundles_for_component_direct(component_name)
      return html if bundles.empty?

      emitted = emitted_bundles

      new_tags = bundles.filter_map do |bundle|
        next if emitted_bundle?(emitted, bundle)

        emitted << bundle
        javascript_include_tag("#{bundle}.js", extname: false)
      end

      return html if new_tags.empty?

      safe_join(new_tags + [html])
    end

    private

    def emitted_bundle?(emitted, bundle)
      canonical = canonical_bundle_name(bundle)
      emitted.any? { |existing| canonical_bundle_name(existing) == canonical }
    end

    def canonical_bundle_name(bundle)
      bundle.to_s.split("/").last
    end

    def emitted_bundles
      # ActionView can instantiate multiple helper contexts during one request.
      # Store emitted bundles in request env so layout + template helpers dedupe.
      if respond_to?(:request, true) && request
        request.env["react_manifest.emitted_bundles"] ||= []
      else
        @emitted_bundles ||= []
      end
    end
  end
end
