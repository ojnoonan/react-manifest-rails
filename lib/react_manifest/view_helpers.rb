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
  #
  # Rails renders the action template before the layout, so react_component
  # tags land in the body first. react_bundle_tag hoists them into its own
  # output (the layout's <head>) so Turbolinks never re-evaluates a body script.
  module ViewHelpers
    INLINE_BUNDLE_TAG = %r{<script\b[^>]*\sdata-react-manifest="([^"]*)"[^>]*></script>}

    def react_bundle_tag(**html_options)
      # controller_path is not available in all view contexts (mailers, engines,
      # views rendered outside a request). Fall back gracefully rather than raising.
      ctrl = respond_to?(:controller_path, true) ? controller_path : nil
      return "".html_safe if ctrl.nil?

      emitted = emitted_bundles
      hoisted = hoist_inline_bundle_tags
      emitted.reject! { |e| hoisted.any? { |h| canonical_bundle_name(h) == canonical_bundle_name(e) } }

      bundles = (ReactManifest.resolve_bundles(ctrl) + hoisted).uniq { |b| canonical_bundle_name(b) }
      return "".html_safe if bundles.empty?

      # Record emitted bundles so react_component doesn't re-emit them.
      fresh_bundles = bundles.reject { |b| emitted_bundle?(emitted, b) }
      return "".html_safe if fresh_bundles.empty?

      fresh_bundles.each { |b| emitted << b }

      tags = fresh_bundles.map do |bundle|
        javascript_include_tag("#{bundle}.js", extname: false, **bundle_tag_options(bundle, html_options))
      end
      safe_join(tags, "\n")
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
        javascript_include_tag("#{bundle}.js", extname: false, data: { react_manifest: bundle })
      end

      return html if new_tags.empty?

      safe_join(new_tags + [html])
    end

    private

    # Turbolinks 5 full-reloads when the tracked head elements differ between pages.
    # ux_shared is identical on every page, so tracking it forces one reload per deploy;
    # tracking controller bundles would reload on every cross-controller visit.
    def bundle_tag_options(bundle, html_options)
      shared = canonical_bundle_name(ReactManifest.configuration.shared_bundle)
      return html_options unless canonical_bundle_name(bundle) == shared

      html_options.merge(data: (html_options[:data] || {}).merge(turbolinks_track: "reload"))
    end

    # Strips the inline tags react_component already wrote into the rendered
    # template (and content_for) buffers; returns their bundle names in order.
    def hoist_inline_bundle_tags
      return [] unless respond_to?(:view_flow, true) && view_flow

      names = []
      view_flow.content.each_key do |key|
        html = view_flow.get(key).to_s
        next unless html.include?("data-react-manifest")

        names.concat(html.scan(INLINE_BUNDLE_TAG).flatten)
        view_flow.set(key, html.gsub(INLINE_BUNDLE_TAG, "").html_safe)
      end
      names
    end

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
