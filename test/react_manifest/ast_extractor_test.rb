require "test_helper"
require "react_manifest/ast_extractor"

class AstExtractorTest < ReactManifestTest
  def test_extract_definitions_finds_pascal_case_const
    assert_equal ["Show"], ReactManifest::AstExtractor.extract_definitions("const Show = () => <div />;\n")
  end

  def test_extract_usages_ignores_plain_jsx_text
    content = "const UsersIndex = () => <button>Show More</button>;\n"
    assert_equal [], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_usages_detects_real_jsx_reference
    content = "const UsersDetail = () => <Show />;\n"
    assert_equal ["Show"], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_usages_detects_lowercase_lib_call
    content = "const result = formatDate(value);\n"
    assert_includes ReactManifest::AstExtractor.extract_usages(content), "formatDate"
  end

  def test_extract_usages_excludes_js_builtins
    content = "fetch('/api').then(r => r.json());\n"
    refute_includes ReactManifest::AstExtractor.extract_usages(content), "fetch"
  end

  def test_extract_usages_excludes_self_reference
    content = "const MyWidget = () => <MyWidget />;\n"
    assert_equal [], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_definitions_returns_nil_and_warns_on_syntax_error
    Rails.logger.expects(:warn).with { |msg| msg.include?("broken.jsx") && msg.include?("line 3") }
    result = ReactManifest::AstExtractor.extract_definitions("const Broken = () => {\n  return <div>\n};\n",
                                                             file_path: "broken.jsx")
    assert_nil result
  end

  def test_extract_usages_returns_nil_and_warns_on_syntax_error
    Rails.logger.expects(:warn).with { |msg| msg.include?("broken.jsx") }
    result = ReactManifest::AstExtractor.extract_usages("const Broken = () => {\n  return <div>\n};\n",
                                                        file_path: "broken.jsx")
    assert_nil result
  end

  def test_warning_omits_filename_when_not_provided
    Rails.logger.expects(:warn).with { |msg| msg.include?("unknown file") }
    ReactManifest::AstExtractor.extract_usages("const Broken = () => {\n  return <div>\n};\n")
  end

  def test_recovers_from_poisoned_context_instead_of_failing_forever
    poisoned_context = mock("poisoned_context")
    poisoned_context.expects(:call).raises(MiniRacer::ContextDisposedError, "V8 isolate disposed")
    ReactManifest::AstExtractor.instance_variable_set(:@context, poisoned_context)

    Rails.logger.expects(:warn).with { |msg| msg.include?("V8 isolate disposed") }
    result = ReactManifest::AstExtractor.extract_usages("const result = formatDate(value);\n", file_path: "poison.jsx")
    assert_nil result

    # The poisoned context must have been discarded so the next call rebuilds a fresh one.
    assert_nil ReactManifest::AstExtractor.instance_variable_get(:@context)

    recovered = ReactManifest::AstExtractor.extract_usages("const result = formatDate(value);\n")
    assert_includes recovered, "formatDate"
  end
end
