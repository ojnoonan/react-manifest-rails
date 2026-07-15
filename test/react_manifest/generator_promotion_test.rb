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
end
