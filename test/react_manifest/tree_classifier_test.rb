require "test_helper"

class TreeClassifierTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @classifier = ReactManifest::TreeClassifier.new(@config)
  end

  def test_identifies_controller_dirs_under_ux_app
    result = @classifier.classify
    names = result.controller_dirs.map { |d| d[:name] }
    assert_includes names, "notifications"
    assert_includes names, "users"
    assert_includes names, "main"
  end

  def test_identifies_shared_dirs_like_components_hooks_lib
    result = @classifier.classify
    names = result.shared_dirs.map { |d| d[:name] }
    assert_includes names, "components"
    assert_includes names, "hooks"
    assert_includes names, "lib"
  end

  def test_shared_dirs_are_not_included_as_controller_dirs
    result = @classifier.classify
    ctrl_names = result.controller_dirs.map { |d| d[:name] }
    refute_includes ctrl_names, "components"
    refute_includes ctrl_names, "hooks"
    refute_includes ctrl_names, "lib"
  end

  def test_assigns_correct_bundle_name_to_each_controller_dir
    result = @classifier.classify
    notif = result.controller_dirs.find { |d| d[:name] == "notifications" }
    assert_equal "ux_notifications", notif[:bundle_name]
  end

  def test_auto_discovers_new_shared_dir_added_at_runtime
    new_dir = File.join(Rails.root.join(@config.ux_root).to_s, "contexts")
    FileUtils.mkdir_p(new_dir)

    result = @classifier.classify
    names = result.shared_dirs.map { |d| d[:name] }
    assert_includes names, "contexts"
  end

  def test_respects_ignore_list_for_controller_dirs
    ReactManifest.configure { |c| c.ignore = ["notifications"] }
    result = @classifier.classify
    names = result.controller_dirs.map { |d| d[:name] }
    refute_includes names, "notifications"
  end

  def test_returns_empty_results_when_ux_root_does_not_exist
    ReactManifest.configure { |c| c.ux_root = "app/assets/javascripts/nonexistent" }
    result = @classifier.classify
    assert_empty result.controller_dirs
    assert_empty result.shared_dirs
  end

  def test_logs_warn_via_rails_logger_when_ux_root_does_not_exist
    ReactManifest.configure { |c| c.ux_root = "app/assets/javascripts/nonexistent" }
    Rails.logger.expects(:warn).with { |msg| msg.include?("ux_root does not exist") }
    @classifier.classify
  end

  def test_watched_dirs_returns_only_existing_paths
    dirs = @classifier.watched_dirs
    dirs.each { |d| assert Dir.exist?(d), "Expected #{d} to exist" }
  end

  def test_watched_dirs_includes_the_app_dir
    dirs = @classifier.watched_dirs
    assert dirs.any? { |d| d.end_with?("/app") }, "Expected watched_dirs to include the app dir"
  end
end
