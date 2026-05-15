require "spec_helper"

RSpec.describe "Integration: watcher-triggered regeneration" do
  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  let(:config) { ReactManifest.configuration }

  def manifest_content(name)
    File.read(File.join(config.abs_manifest_dir, name))
  end

  def trigger_change(changed_paths)
    changed_paths.each { |f| ReactManifest::Scanner.invalidate(f) }
    ReactManifest::Generator.new(config).run!
  end

  it "adding a new controller file causes it to appear in the controller manifest" do
    ReactManifest::Generator.new(config).run!

    new_file = Rails.root.join("app/assets/javascripts/ux/app/users/users_profile.js.jsx")
    File.write(new_file, "const UsersProfile = () => React.createElement('div', null, 'Profile');\n")

    trigger_change([new_file.to_s])

    expect(manifest_content("ux_users.js")).to include("ux/app/users/users_profile")
  end

  it "removing a controller file causes it to disappear from the controller manifest" do
    ReactManifest::Generator.new(config).run!
    expect(manifest_content("ux_notifications.js")).to include("notifications_show")

    removed_file = Rails.root.join("app/assets/javascripts/ux/app/notifications/notifications_show.js.jsx")
    File.delete(removed_file)

    trigger_change([removed_file.to_s])

    expect(manifest_content("ux_notifications.js")).not_to include("notifications_show")
  end

  it "modifying a shared file that a controller uses causes the shared manifest to update" do
    ReactManifest::Generator.new(config).run!

    new_shared = Rails.root.join("app/assets/javascripts/ux/components/new_widget.js")
    File.write(new_shared, "const NewWidget = () => React.createElement('span', null);\n")

    trigger_change([new_shared.to_s])

    expect(manifest_content("ux_shared.js")).to include("ux/components/new_widget")
  end
end
