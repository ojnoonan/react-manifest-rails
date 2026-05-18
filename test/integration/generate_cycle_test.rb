require "test_helper"

class GenerateCycleTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    ReactManifest::Generator.new(@config).run!
  end

  def manifest(name)
    File.read(File.join(@config.abs_manifest_dir, name))
  end

  def test_writes_ux_shared_js_with_shared_component_requires
    content = manifest("ux_shared.js")
    assert_includes content, "//= require ux/components/buttons/primary_button"
    assert_includes content, "//= require ux/hooks/use_fetch"
    assert_includes content, "//= require ux/lib/api_helpers"
  end

  def test_writes_a_per_controller_manifest_for_each_app_subdirectory
    %w[ux_users.js ux_notifications.js ux_orders.js ux_products.js].each do |name|
      assert File.exist?(File.join(@config.abs_manifest_dir, name)), "#{name} does not exist"
    end
  end

  def test_controller_manifest_does_not_inline_shared_source_files
    content = manifest("ux_notifications.js")
    refute_includes content, "ux/components/"
    refute_includes content, "ux/hooks/"
    refute_includes content, "ux/lib/"
  end

  def test_controller_manifest_requires_its_own_controller_files
    content = manifest("ux_notifications.js")
    assert_includes content, "//= require ux/app/notifications/notifications_index"
    assert_includes content, "//= require ux/app/notifications/notifications_show"
  end

  def test_all_generated_manifests_carry_the_auto_generated_header
    Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js")).each do |path|
      assert_includes File.read(path), "AUTO-GENERATED", "#{File.basename(path)} is missing AUTO-GENERATED header"
    end
  end
end
