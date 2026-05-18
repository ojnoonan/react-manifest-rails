require "test_helper"

class ApplicationAnalyzerTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @analyzer = ReactManifest::ApplicationAnalyzer.new(@config)
  end

  def test_finds_application_js_and_application_dev_js
    results = @analyzer.analyze
    filenames = results.map { |r| File.basename(r.file) }
    assert_includes filenames, "application.js"
    assert_includes filenames, "application_dev.js"
  end

  def test_classifies_react_requires_as_vendor_keep
    result = @analyzer.analyze.find { |r| r.file.end_with?("application.js") }
    vendor = result.vendor_lines.map(&:path)
    assert_includes vendor, "react/react.min"
    assert_includes vendor, "react/react-dom.min"
    assert_includes vendor, "react/mui.min"
  end

  def test_classifies_require_tree_ux_as_ux_code_remove
    result = @analyzer.analyze.find { |r| r.file.end_with?("application.js") }
    ux_lines = result.ux_code_lines
    refute_empty ux_lines
    assert(ux_lines.any? { |l| l.directive.include?("tree") })
  end

  def test_application_js_is_not_clean_because_it_has_ux_code
    result = @analyzer.analyze.find { |r| r.file.end_with?("application.js") }
    refute result.clean?
  end

  def test_clean_application_js_with_only_vendor_requires_reports_clean_true
    clean_content = "//= require react/react.min\n//= require react/react-dom.min\n"
    path = File.join(@config.abs_output_dir, "application_clean.js")
    File.write(path, clean_content)

    results = @analyzer.analyze
    clean_result = results.find { |r| r.file.end_with?("application_clean.js") }
    assert clean_result.clean?
  end
end
