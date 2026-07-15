require "test_helper"

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

  def test_symbol_collision_promotes_only_the_canonical_definer
    write_ux("app/reports/reports_widget.js.jsx", "const Widget = () => <div>reports</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/dashboard/dashboard_index.js.jsx", "const DashboardIndex = () => <Widget />;\n")

    ReactManifest::Generator.new(@config).run!

    shared = read_manifest("ux_shared.js")
    assert_equal(1, ["ux/app/reports/reports_widget", "ux/app/orders/orders_widget"].count { |p| shared.include?(p) })
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

  def test_always_include_private_file_is_not_promoted_and_loads_everywhere
    ReactManifest.configure { |c| c.always_include = ["ux_navbar"] }
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <NavbarPrivate />;\n")
    write_ux("app/navbar/navbar_private.js.jsx", "const NavbarPrivate = () => <div />;\n")
    write_ux("app/reports/reports_index.js.jsx", "const ReportsIndex = () => <div />;\n")
    ReactManifest::Generator.new(@config).run!

    # navbar_private is used only inside navbar -> not promoted; stays in ux_navbar
    # and is force-included into other controllers via always_include.
    refute_includes read_manifest("ux_shared.js"), "ux/app/navbar/navbar_private"
    assert_includes read_manifest("ux_navbar.js"), "ux/app/navbar/navbar_private"
    assert_includes read_manifest("ux_reports.js"), "ux/app/navbar/navbar_private"
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
end
