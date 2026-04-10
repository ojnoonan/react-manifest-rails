module ReactManifest
  # Provides the `react_bundle_tag` view helper, included in ActionView::Base.
  #
  # Usage in layouts:
  #   <%= react_bundle_tag defer: true %>
  #
  # Resolves which ux_*.js bundles to include based on controller_name:
  #   1. Always includes config.shared_bundle (e.g. "ux_shared")
  #   2. Always appends config.always_include (e.g. ["ux_main"])
  #   3. Appends "ux_<controller_name>" if that bundle file exists
  #   4. For namespaced controllers (admin/users): checks ux_admin_users, then ux_admin
  #   5. Returns "" for pure ERB/HAML pages with no matching bundle
  module ViewHelpers
    def react_bundle_tag(**html_options)
      bundles = ReactManifest.resolve_bundles(controller_name)
      return "".html_safe if bundles.empty?
      javascript_include_tag(*bundles, **html_options)
    end
  end
end
