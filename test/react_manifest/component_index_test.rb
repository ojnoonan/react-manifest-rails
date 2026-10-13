require "test_helper"

class ComponentIndexTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @ux = File.join(@tmpdir, "app/assets/javascripts/ux")
  end

  def sidecar
    ReactManifest::ComponentIndex.path(@config)
  end

  def classify
    ReactManifest::TreeClassifier.new(@config).classify.controller_dirs
  end

  def write_ux(rel, content)
    path = File.join(@ux, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def test_generate_writes_sidecar_next_to_manifests
    ReactManifest::Generator.new(@config).run!

    assert_equal File.join(@config.abs_manifest_dir, "component_index.json"), sidecar
    assert File.exist?(sidecar)
  end

  def test_sidecar_maps_equal_parsed_maps
    ReactManifest::Generator.new(@config).run!
    parsed = ReactManifest::ComponentIndex.build(@config, classify)

    ReactManifest::ComponentIndex.expects(:build).never
    loaded = ReactManifest::ComponentIndex.maps(@config)

    refute_empty parsed[:symbol_to_bundle]
    assert_equal parsed, loaded
    assert_equal parsed[:bundle_dependencies].keys, loaded[:bundle_dependencies].keys
  end

  def test_sidecar_with_dependencies_round_trips
    write_ux("app/orders/orders_index.js.jsx", "const OrdersIndex = () => <UsersIndex />;\n")
    ReactManifest::Generator.new(@config).run!
    parsed = ReactManifest::ComponentIndex.build(@config, classify)

    assert_includes parsed[:bundle_dependencies]["ux_orders"], "ux_users"
    assert_equal parsed, ReactManifest::ComponentIndex.maps(@config)
  end

  def test_falls_back_to_parsing_when_sidecar_is_missing_or_corrupt
    ReactManifest::Generator.new(@config).run!
    expected = ReactManifest::ComponentIndex.build(@config, classify)

    File.delete(sidecar)
    assert_equal expected, ReactManifest::ComponentIndex.maps(@config)

    File.write(sidecar, "{not json")
    assert_equal expected, ReactManifest::ComponentIndex.maps(@config)
  end

  def test_edited_source_makes_the_sidecar_stale
    ReactManifest::Generator.new(@config).run!
    write_ux("app/users/users_added.js.jsx", "const UsersAdded = () => <div />;\n")

    maps = ReactManifest::ComponentIndex.maps(@config)

    assert_equal "ux_users", maps[:symbol_to_bundle]["UsersAdded"]
  end

  def test_config_change_makes_the_sidecar_stale
    ReactManifest::Generator.new(@config).run!
    write_ux("app/users/users_ts.tsx", "const UsersTs = () => <div />;\n")
    @config.extensions = %w[js jsx tsx]

    ReactManifest::ComponentIndex.expects(:build).once.returns({})
    ReactManifest::ComponentIndex.maps(@config)
  end

  def test_dry_run_does_not_write_the_sidecar
    @config.dry_run = true
    ReactManifest::Generator.new(@config).run!

    refute File.exist?(sidecar)
  end

  def test_clean_removes_the_sidecar
    ReactManifest::Generator.new(@config).run!
    ReactManifest::Generator.new(@config).clean!

    refute File.exist?(sidecar)
  end

  def test_rewriting_unchanged_index_leaves_file_untouched
    ReactManifest::Generator.new(@config).run!
    before = File.mtime(sidecar)
    sleep 0.01
    ReactManifest::Generator.new(@config).run!

    assert_equal before, File.mtime(sidecar)
  end
end

class GeneratorCheckTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @ux = File.join(@tmpdir, "app/assets/javascripts/ux")
    $stdout.stubs(:puts)
  end

  def write_ux(rel, content)
    path = File.join(@ux, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def test_check_is_empty_for_a_clean_tree
    assert_empty ReactManifest::Generator.new(@config).check
  end

  def test_check_returns_cross_bundle_lexical_clashes_and_writes_nothing
    write_ux("app/tasks/tasks_form.js.jsx", "const validateLength = 1;\nconst TasksForm = () => <div />;\n")
    write_ux("app/projects/projects_form.js.jsx", "const validateLength = 2;\nconst ProjectsForm = () => <div />;\n")

    clashes = ReactManifest::Generator.new(@config).check

    assert_equal 1, clashes.size
    assert_includes clashes.first, "Top-level binding 'validateLength'"
    refute Dir.exist?(@config.abs_manifest_dir)
  end

  def test_check_returns_always_include_double_declares
    @config.always_include = ["ux_navbar"]
    write_ux("app/billing/billing_widget.js.jsx", "const Widget = () => <div>billing</div>;\n")
    write_ux("app/orders/orders_widget.js.jsx", "const Widget = () => <div>orders</div>;\n")
    write_ux("app/navbar/navbar.js.jsx", "const Navbar = () => <Widget />;\n")

    clashes = ReactManifest::Generator.new(@config).check

    assert(clashes.any? { |m| m.include?("always_include") && m.include?("twice") }, clashes.to_s)
  end

  def test_check_does_not_accumulate_across_calls
    write_ux("app/tasks/tasks_form.js.jsx", "const validateLength = 1;\n")
    write_ux("app/projects/projects_form.js.jsx", "const validateLength = 2;\n")
    gen = ReactManifest::Generator.new(@config)

    assert_equal gen.check.size, gen.check.size
  end
end
