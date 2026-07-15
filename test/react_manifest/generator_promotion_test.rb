require "test_helper"

# rubocop:disable Metrics/ClassLength
class GeneratorPromotionTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def write_ux(rel, content)
    path = Rails.root.join("app/assets/javascripts/ux", rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def read_manifest(name)
    File.read(File.join(@config.abs_manifest_dir, name), encoding: "utf-8")
  end

  def test_component_used_by_another_controller_is_promoted_to_shared
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_reports.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_common.js"), "ux/app/common/export_form"
  end

  def test_private_component_stays_in_its_own_bundle
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ReportsPrivate />;\n")
    write_ux("app/reports/reports_private.js.jsx", "const ReportsPrivate = () => <div />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_reports.js"), "ux/app/reports/reports_private"
    refute_includes read_manifest("ux_shared.js"), "ux/app/reports/reports_private"
  end

  def test_transitive_dependency_of_a_promoted_file_is_also_promoted
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <ExportRow />;\n")
    write_ux("app/common/export_row.js.jsx", "const ExportRow = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_row"
  end

  def test_mutual_use_cycle_terminates_and_promotes_both
    write_ux("app/common/alpha.js.jsx", "const Alpha = () => <Beta />;\n")
    write_ux("app/common/beta.js.jsx",  "const Beta = () => <Alpha />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Alpha />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/alpha"
    assert_includes read_manifest("ux_shared.js"), "ux/app/common/beta"
  end

  def test_diamond_dependency_promotes_shared_leaf_once
    write_ux("app/common/leaf.js.jsx", "const Leaf = () => <div />;\n")
    write_ux("app/common/top_a.js.jsx", "const TopA = () => <Leaf />;\n")
    write_ux("app/common/top_b.js.jsx", "const TopB = () => <Leaf />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div><TopA /><TopB /></div>;\n")

    ReactManifest::Generator.new(@config).run!

    shared = read_manifest("ux_shared.js")
    assert_equal(1, shared.lines.count { |l| l.strip == "//= require ux/app/common/leaf" },
                 "leaf should be required exactly once")
  end

  def test_isolated_app_dir_file_is_not_promoted
    ReactManifest.configure { |c| c.isolated_app_dirs = ["rvb"] }
    @config = ReactManifest.configuration

    write_ux("app/rvb/rvb_show.js.jsx", "const Show = () => <div>rvb</div>;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Show />;\n")

    ReactManifest::Generator.new(@config).run!

    refute_includes read_manifest("ux_shared.js"), "ux/app/rvb/rvb_show"
    assert_includes read_manifest("ux_rvb.js"), "ux/app/rvb/rvb_show"
  end

  def test_symbol_collision_keeps_both_definers_out_of_shared
    write_ux("app/reports/reports_widget.js.jsx", "const Widget = () => <div>reports</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/dashboard/dashboard_index.js.jsx", "const DashboardIndex = () => <Widget />;\n")

    ReactManifest::Generator.new(@config).run!

    refute_includes read_manifest("ux_shared.js"), "ux/app/orders/orders_widget"
    refute_includes read_manifest("ux_shared.js"), "ux/app/reports/reports_widget"
    assert_includes read_manifest("ux_reports.js"), "ux/app/reports/reports_widget"
    refute_includes read_manifest("ux_reports.js"), "ux/app/orders/orders_widget" # reports page: no double
    # consumer gets first-writer via legacy inline
    assert_includes read_manifest("ux_dashboard.js"), "ux/app/orders/orders_widget"
  end

  def test_promotion_does_not_over_inline_unrelated_dep_bundle_files
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/notification/show_component.js.jsx", "const Show = () => <div />;\n")
    write_ux("app/notification/notifications_index.js.jsx", "const NotificationsIndex = () => <div />;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Show />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/notification/show_component" # Show promoted
    # NOT over-inlined into navbar (would double against ux_notification on the notification page)
    refute_includes read_manifest("ux_navbar.js"), "ux/app/notification/notifications_index"
    assert_includes read_manifest("ux_notification.js"), "ux/app/notification/notifications_index"
  end

  def test_promoted_file_depending_on_collided_symbol_falls_back_to_legacy
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/reports/reports_widget.js.jsx", "const Widget = () => <div>reports</div>;\n")
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <Widget />;\n")
    write_ux("app/billing/billing_index.js.jsx", "const BillingIndex = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    # tainted (depends on collided Widget) -> not promoted
    refute_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    assert_includes read_manifest("ux_billing.js"), "ux/app/common/export_form" # inlined per-consumer
    # transitive first-writer Widget so ExportForm renders
    assert_includes read_manifest("ux_billing.js"), "ux/app/orders/orders_widget"
  end

  def test_shared_dir_file_referencing_a_controller_symbol_promotes_it
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("components/exporter.js.jsx", "const Exporter = () => <ExportForm />;\n")

    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_common.js"), "ux/app/common/export_form"
  end

  # ---- single-emission invariant -------------------------------------------

  def requires_in(name)
    read_manifest(name).lines.filter_map do |l|
      l.strip.start_with?("//= require") ? l.strip.sub("//= require ", "") : nil
    end
  end

  def controller_manifest_names
    Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
       .map { |p| File.basename(p) }
       .reject { |n| n == "ux_shared.js" }
  end

  def test_no_require_appears_in_both_shared_and_a_controller_bundle
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    shared = requires_in("ux_shared.js").to_set
    controller_manifest_names.each do |name|
      overlap = shared & requires_in(name).to_set
      assert_empty overlap, "#{name} duplicates shared requires: #{overlap.to_a}"
    end
  end

  def test_no_require_appears_in_two_controller_bundles
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    write_ux("app/billing/billing_index.js.jsx", "const BillingIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    seen = {}
    controller_manifest_names.each do |name|
      requires_in(name).each do |req|
        assert_nil seen[req], "#{req} appears in #{seen[req]} and #{name}"
        seen[req] = name
      end
    end
  end

  # ---- regression: the reported navbar + always_include bug -----------------

  def test_navbar_always_include_no_longer_double_declares_shared_component
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/notification/show_component.js.jsx", "const Show = () => <div />;\n")
    write_ux("app/notification/notifications_index.js.jsx", "const NotificationsIndex = () => <div />;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Show />;\n")
    ReactManifest::Generator.new(@config).run!

    assert_includes read_manifest("ux_shared.js"), "ux/app/notification/show_component"
    refute_includes read_manifest("ux_navbar.js"), "ux/app/notification/show_component"
    refute_includes read_manifest("ux_notification.js"), "ux/app/notification/show_component"
    # notification-specific file stays put (not over-hoisted)
    assert_includes read_manifest("ux_notification.js"), "ux/app/notification/notifications_index"
  end

  # ---- always_include private file still loads, not promoted ----------------

  # An always_include bundle is delivered on every page by its own <script> tag
  # (resolve_bundles / react_component both emit it). Its private files must
  # therefore live ONLY in that bundle's manifest — never inlined into other
  # controllers, or they would load twice on a page and double-declare.
  def test_always_include_private_file_is_not_promoted_and_not_inlined_elsewhere
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <NavbarPrivate />;\n")
    write_ux("app/navbar/navbar_private.js.jsx", "const NavbarPrivate = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div />;\n")
    ReactManifest::Generator.new(@config).run!

    # navbar_private is used only inside navbar -> not promoted; stays in ux_navbar
    # and reaches other pages via the ux_navbar <script> tag, NOT by inlining.
    refute_includes read_manifest("ux_shared.js"), "ux/app/navbar/navbar_private"
    assert_includes read_manifest("ux_navbar.js"), "ux/app/navbar/navbar_private"
    refute_includes read_manifest("ux_reports.js"), "ux/app/navbar/navbar_private"
  end

  # ---- page-level: no file loaded twice across a page's resolved bundles -----

  # The set of files a page actually loads is the union of requires across every
  # bundle resolve_bundles returns: [ux_shared, <always_include...>, ux_<ctrl>].
  # Sprockets dedupes within one manifest but NOT across separately-compiled
  # manifests, so a require appearing in two of these = a runtime double declare.
  def page_requires(controller_bundle, always: [])
    (requires_in("ux_shared.js") +
     always.flat_map { |b| requires_in("#{b}.js") } +
     requires_in("#{controller_bundle}.js"))
  end

  def test_always_include_private_file_not_double_loaded_on_another_page
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <NavbarPrivate />;\n")
    write_ux("app/navbar/navbar_private.js.jsx", "const NavbarPrivate = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div />;\n")
    ReactManifest::Generator.new(@config).run!

    page = page_requires("ux_reports", always: ["ux_navbar"])
    assert_equal page.uniq, page, "no file may load twice on the reports page: #{page.tally.select { |_, n| n > 1 }}"
    assert_equal 1, page.count("ux/app/navbar/navbar_private"),
                 "navbar_private loads exactly once (via the ux_navbar tag)"
  end

  # The reported repro: a symbol collides across two app dirs, and one definer
  # lives in an always_include bundle. The consumer must resolve that symbol to
  # the always-loaded definer (delivered by the always_include tag) and inline
  # NO second definer of its own — otherwise both `const Widget` files load on
  # the same page.
  def test_always_include_collided_symbol_resolves_to_always_definer_only
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/aaa/aaa_widget.js.jsx", "const Widget = () => <div>aaa</div>;\n")
    write_ux("app/navbar/navbar_widget.js.jsx", "const Widget = () => <div>navbar</div>;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Widget />;\n")
    ReactManifest::Generator.new(@config).run!

    page = page_requires("ux_reports", always: ["ux_navbar"])
    # Widget is provided on every page by the ux_navbar tag; reports inlines no copy.
    refute_includes page, "ux/app/aaa/aaa_widget"
    assert_equal 1, page.count("ux/app/navbar/navbar_widget"),
                 "exactly one file defines Widget on the reports page"
    refute_includes read_manifest("ux_reports.js"), "ux/app/aaa/aaa_widget"
  end

  # Residual edge: the always_include bundle does not DEFINE the collided symbol
  # but CONSUMES it, so its own tag inlines a first-writer definer. A different
  # controller using the same collided symbol must resolve to that same
  # always-loaded definer (or nothing) — never inline a second copy on its page.
  def test_always_include_bundle_consuming_collided_symbol_no_double_elsewhere
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/billing/billing_widget.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Widget />;\n")
    ReactManifest::Generator.new(@config).run!

    widget_files = %w[ux/app/billing/billing_widget ux/app/orders/orders_widget]

    # navbar's tag pulls in exactly one first-writer Widget definer.
    navbar = requires_in("ux_navbar.js")
    assert_equal 1, widget_files.count { |f| navbar.include?(f) },
                 "navbar tag defines Widget exactly once: #{navbar}"

    # On the reports page (ux_shared + ux_navbar + ux_reports) Widget is defined once.
    page = page_requires("ux_reports", always: ["ux_navbar"])
    assert_equal 1, widget_files.sum { |f| page.count(f) },
                 "Widget must be defined exactly once on the reports page: #{page}"
    widget_files.each { |f| refute_includes read_manifest("ux_reports.js"), f }
  end

  # Same residual, but transitively: navbar consumes Foo (private to a dep bundle),
  # whose file also defines the collided Widget. Another controller using Widget
  # must not re-inline that dep file already delivered by the navbar tag.
  def test_always_include_transitive_dep_file_not_re_inlined_by_other_controller
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    # billing_widget defines BOTH a collided Widget and a private Extra.
    write_ux("app/billing/billing_widget.js.jsx",
             "const Widget = () => <div>billing</div>;\nconst Extra = () => <div />;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Extra />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Widget />;\n")
    ReactManifest::Generator.new(@config).run!

    # navbar tag delivers billing_widget (for Extra). reports uses Widget, whose
    # first writer is that same billing_widget — it must NOT re-inline it.
    assert_includes requires_in("ux_navbar.js"), "ux/app/billing/billing_widget"
    page = page_requires("ux_reports", always: ["ux_navbar"])
    assert_equal 1, page.count("ux/app/billing/billing_widget"),
                 "billing_widget loads exactly once on the reports page: #{page}"
    refute_includes read_manifest("ux_reports.js"), "ux/app/billing/billing_widget"
  end

  # Legacy (auto_shared = false): the always_include bundle inlines whole dep
  # bundles into its tag; other controllers must not inline those same bundles.
  def test_legacy_always_include_dep_bundle_not_double_loaded
    ReactManifest.configure do |c|
      c.auto_shared = false
      c.always_include = ["ux_navbar"]
    end
    write_ux("app/billing/billing_widget.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Widget />;\n")
    ReactManifest::Generator.new(@config).run!

    widget_files = %w[ux/app/billing/billing_widget ux/app/orders/orders_widget]
    page = page_requires("ux_reports", always: ["ux_navbar"])
    assert_equal 1, widget_files.sum { |f| page.count(f) },
                 "Widget must be defined exactly once on the reports page (legacy): #{page}"
  end

  # Guards against UNDER-inlining: the always_include bundle depends on ONE file
  # of a dep bundle, but that bundle owns a SECOND, unpromotable file the tag does
  # NOT carry. A consumer needing a symbol from that second file must still inline
  # it — treating "every symbol the dep bundle owns" as always-provided would drop
  # it and yield `X is not defined` at runtime.
  def test_symbol_from_dep_bundle_file_not_on_always_tag_is_still_inlined
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    # billing owns two files. billing_a defines the collided Widget the navbar
    # uses; billing_b defines Gizmo AND a collided Widget2 (making billing_b
    # unpromotable, so Gizmo can't be hoisted to ux_shared).
    write_ux("app/billing/billing_a.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/billing/billing_b.js.jsx",
             "const Gizmo = () => <div />;\nconst Widget2 = () => <div>billing2</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/things/things_widget2.js.jsx", "const Widget2 = () => <div>things</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <Gizmo />;\n")
    ReactManifest::Generator.new(@config).run!

    # navbar's tag carries billing_a (for Widget) but NOT billing_b.
    refute_includes requires_in("ux_navbar.js"), "ux/app/billing/billing_b"
    # Gizmo lives only in billing_b, which is NOT on the navbar tag, so reports
    # must inline it — otherwise Gizmo is undefined on the reports page.
    assert_includes read_manifest("ux_reports.js"), "ux/app/billing/billing_b"
  end

  # ---- warning: always_include bundle consumes a collided symbol -------------

  def capture_warnings
    warn_calls = []
    $stdout.stubs(:puts)
    Rails.logger.stubs(:warn).with do |msg|
      warn_calls << msg
      true
    end
    yield
    warn_calls
  end

  # This is the inherent limitation dependency arithmetic cannot resolve: when an
  # always_include bundle consumes a collided symbol, its tag inlines the
  # first-writer definer, which ALSO lives in that definer's own bundle manifest —
  # so on the definer's own page the file loads twice. We can't auto-fix it, but
  # we surface it so the author can rename/relocate the symbol.
  def test_always_include_consuming_collided_symbol_warns_about_double_load
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/billing/billing_widget.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")

    warnings = capture_warnings { ReactManifest::Generator.new(@config).run! }

    assert(warnings.any? do |m|
      m.include?("always_include") && m.include?("ux_navbar") &&
        m.include?("ux/app/billing/billing_widget") && m.include?("ux_billing") &&
        m.include?("Widget") && m.include?("twice")
    end, "expected a double-load warning, got: #{warnings}")
  end

  def test_always_include_consuming_collided_symbol_warns_in_legacy_mode
    ReactManifest.configure do |c|
      c.auto_shared = false
      c.always_include = ["ux_navbar"]
    end
    write_ux("app/billing/billing_widget.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")

    warnings = capture_warnings { ReactManifest::Generator.new(@config).run! }

    assert(warnings.any? { |m| m.include?("ux_navbar") && m.include?("twice") },
           "expected a legacy double-load warning, got: #{warnings}")
  end

  # No collision => no warning: a cross-used non-collided symbol is promoted to
  # ux_shared (loaded once per page), so nothing double-loads.
  def test_always_include_using_promoted_symbol_does_not_warn
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/notification/show_component.js.jsx", "const Show = () => <div />;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Show />;\n")

    warnings = capture_warnings { ReactManifest::Generator.new(@config).run! }

    refute(warnings.any? { |m| m.include?("twice") },
           "no double-load warning expected, got: #{warnings}")
  end

  def test_auto_shared_false_restores_legacy_inline_behavior
    ReactManifest.configure { |c| c.auto_shared = false }
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")
    ReactManifest::Generator.new(@config).run!

    # Legacy: cross-app dep inlined into the consumer, nothing promoted to shared.
    assert_includes read_manifest("ux_reports.js"), "ux/app/common/export_form"
    refute_includes read_manifest("ux_shared.js"), "ux/app/common/export_form"
  end

  def test_promotion_reasons_are_exposed_for_reporting
    write_ux("app/common/export_form.js.jsx", "const ExportForm = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <ExportForm />;\n")

    gen = ReactManifest::Generator.new(@config)
    reasons = gen.promotion_reasons
    key = "ux/app/common/export_form"
    assert reasons.key?(key), "expected #{key} in promotion reasons: #{reasons.keys}"
    assert_includes reasons[key], "ux_reports"
  end
end
# rubocop:enable Metrics/ClassLength
