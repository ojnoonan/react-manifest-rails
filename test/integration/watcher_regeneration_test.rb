require "test_helper"

class WatcherRegenerationTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
  end

  def manifest_content(name)
    File.read(File.join(@config.abs_manifest_dir, name))
  end

  def trigger_change(changed_paths)
    changed_paths.each { |f| ReactManifest::Scanner.invalidate(f) }
    ReactManifest::Generator.new(@config).run!
  end

  def test_adding_a_new_controller_file_causes_it_to_appear_in_the_controller_manifest
    ReactManifest::Generator.new(@config).run!

    new_file = Rails.root.join("app/assets/javascripts/ux/app/users/users_profile.js.jsx")
    File.write(new_file, "const UsersProfile = () => React.createElement('div', null, 'Profile');\n")

    trigger_change([new_file.to_s])

    assert_includes manifest_content("ux_users.js"), "ux/app/users/users_profile"
  end

  def test_removing_a_controller_file_causes_it_to_disappear_from_the_controller_manifest
    ReactManifest::Generator.new(@config).run!
    assert_includes manifest_content("ux_notifications.js"), "notifications_show"

    removed_file = Rails.root.join("app/assets/javascripts/ux/app/notifications/notifications_show.js.jsx")
    File.delete(removed_file)

    trigger_change([removed_file.to_s])

    refute_includes manifest_content("ux_notifications.js"), "notifications_show"
  end

  def test_modifying_a_shared_file_causes_the_shared_manifest_to_update
    ReactManifest::Generator.new(@config).run!

    new_shared = Rails.root.join("app/assets/javascripts/ux/components/new_widget.js")
    File.write(new_shared, "const NewWidget = () => React.createElement('span', null);\n")

    trigger_change([new_shared.to_s])

    assert_includes manifest_content("ux_shared.js"), "ux/components/new_widget"
  end
end
