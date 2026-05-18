require "test_helper"

class LayoutPatcherTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @patcher = ReactManifest::LayoutPatcher.new(@config)
  end

  def layouts_dir
    Rails.root.join("app", "views", "layouts").to_s
  end

  def layout_path(name)
    File.join(layouts_dir, name)
  end

  def read_layout(name)
    File.read(layout_path(name), encoding: "utf-8")
  end

  def test_erb_layout_inserts_react_bundle_tag_after_javascript_include_tag
    @patcher.patch!
    content = read_layout("application.html.erb")
    lines = content.lines
    js_idx = lines.index { |l| l.include?("javascript_include_tag") }
    next_ln = lines[js_idx + 1]
    assert_includes next_ln, "react_bundle_tag"
  end

  def test_erb_layout_uses_erb_syntax
    @patcher.patch!
    content = read_layout("application.html.erb")
    assert_includes content, "<%= react_bundle_tag"
  end

  def test_erb_layout_preserves_indentation_of_javascript_include_tag
    @patcher.patch!
    content = read_layout("application.html.erb")
    lines = content.lines
    js_idx = lines.index { |l| l.include?("javascript_include_tag") }
    js_indent  = lines[js_idx][/^\s*/]
    rbt_indent = lines[js_idx + 1][/^\s*/]
    assert_equal js_indent, rbt_indent
  end

  def test_erb_layout_returns_status_patched
    results = @patcher.patch!
    erb_result = results.find { |r| r.file.end_with?(".erb") }
    assert_equal :patched, erb_result.status
  end

  def test_haml_layout_inserts_react_bundle_tag_after_javascript_include_tag
    @patcher.patch!
    content = read_layout("application.html.haml")
    lines = content.lines
    js_idx = lines.index { |l| l.include?("javascript_include_tag") }
    next_ln = lines[js_idx + 1]
    assert_includes next_ln, "react_bundle_tag"
  end

  def test_haml_layout_uses_haml_syntax
    @patcher.patch!
    content = read_layout("application.html.haml")
    refute_includes content, "<%="
    assert_match(/^\s+= react_bundle_tag/, content)
  end

  def test_haml_layout_returns_status_patched
    results = @patcher.patch!
    haml_result = results.find { |r| r.file.end_with?(".haml") }
    assert_equal :patched, haml_result.status
  end

  def test_already_patched_layout_returns_already_patched_and_does_not_duplicate
    path = layout_path("application.html.erb")
    File.write(path, "#{File.read(path)}\n<%= react_bundle_tag %>\n")

    results = @patcher.patch!
    erb_result = results.find { |r| r.file.end_with?(".erb") }
    assert_equal :already_patched, erb_result.status

    content = read_layout("application.html.erb")
    assert_equal 1, content.scan("react_bundle_tag").size
  end

  def test_layout_without_javascript_include_tag_inserts_before_head_close
    path = layout_path("application.html.erb")
    File.write(path, <<~ERB)
      <!DOCTYPE html>
      <html>
        <head>
          <title>Bare</title>
        </head>
        <body><%= yield %></body>
      </html>
    ERB

    @patcher.patch!
    content = read_layout("application.html.erb")
    lines = content.lines
    head_close_idx = lines.rindex { |l| l.include?("</head>") }
    before_head = lines[head_close_idx - 1]
    assert_includes before_head, "react_bundle_tag"
  end

  def test_layout_without_javascript_include_tag_returns_status_patched
    path = layout_path("application.html.erb")
    File.write(path, <<~ERB)
      <!DOCTYPE html>
      <html>
        <head></head>
        <body><%= yield %></body>
      </html>
    ERB

    results = @patcher.patch!
    erb_result = results.find { |r| r.file.end_with?(".erb") }
    assert_equal :patched, erb_result.status
  end

  def test_layout_with_no_injection_point_returns_no_injection_point
    path = layout_path("application.html.erb")
    File.write(path, "<html><body>plain</body></html>")

    results = @patcher.patch!
    erb_result = results.find { |r| r.file.end_with?(".erb") }
    assert_equal :no_injection_point, erb_result.status
  end

  def test_layout_with_no_injection_point_does_not_modify_file
    path = layout_path("application.html.erb")
    original = "<html><body>plain</body></html>"
    File.write(path, original)

    @patcher.patch!
    assert_equal original, read_layout("application.html.erb")
  end

  def test_dry_run_mode_returns_acceptable_statuses
    ReactManifest.configure { |c| c.dry_run = true }
    results = ReactManifest::LayoutPatcher.new(@config).patch!
    results.each do |r|
      assert_includes %i[dry_run already_patched no_injection_point], r.status
    end
  end

  def test_dry_run_mode_does_not_modify_any_layout_file
    originals = {
      "application.html.erb" => read_layout("application.html.erb"),
      "application.html.haml" => read_layout("application.html.haml")
    }
    ReactManifest.configure { |c| c.dry_run = true }
    ReactManifest::LayoutPatcher.new(@config).patch!
    originals.each do |name, original|
      assert_equal original, read_layout(name)
    end
  end

  def test_returns_empty_array_when_no_layouts_directory_exists
    FileUtils.rm_rf(Rails.root.join("app", "views", "layouts").to_s)
    result = @patcher.patch!
    assert_equal [], result
  end

  def test_leaves_original_layout_unchanged_when_write_interrupted
    original = read_layout("application.html.erb")
    File.stubs(:rename).raises(Errno::ENOSPC, "No space left on device")

    assert_raises(Errno::ENOSPC) { @patcher.patch! }

    assert_equal original, read_layout("application.html.erb")
  end

  def test_does_not_leave_tmp_file_when_write_interrupted
    File.stubs(:rename).raises(Errno::ENOSPC, "No space left on device")

    assert_raises(Errno::ENOSPC) { @patcher.patch! }

    assert_empty Dir.glob(File.join(layouts_dir, "*.tmp.*"))
  end
end
