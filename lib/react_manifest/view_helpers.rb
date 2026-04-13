module ReactManifest
  # Provides the `react_bundle_tag` view helper, included in ActionView::Base.
  #
  # Usage in layouts:
  #   <%= react_bundle_tag defer: true %>
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

      javascript_include_tag(*bundles, **html_options)
    end
  end
end
