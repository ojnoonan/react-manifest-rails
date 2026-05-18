require "test_helper"

class SymbolExtractorTest < ReactManifestTest
  # --- extract_definitions: CommonJS style ---

  def test_detects_const_pascal_case_definition
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("const FooBar = () => {};"), "FooBar"
  end

  def test_detects_let_pascal_case_definition
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("let MyComp = () => {};"), "MyComp"
  end

  def test_detects_var_pascal_case_definition
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("var OldStyle = () => {};"), "OldStyle"
  end

  def test_detects_function_declaration
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("function Toolbar() {}"), "Toolbar"
  end

  def test_detects_class_declaration_with_brace
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("class Modal {"), "Modal"
  end

  def test_detects_class_declaration_with_extends
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("class AdminPanel extends Component {"),
                    "AdminPanel"
  end

  # --- extract_definitions: hook patterns ---

  def test_detects_const_hook_definition
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("const useAuth = () => {};"), "useAuth"
  end

  def test_detects_function_hook_declaration
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("function useTheme() {}"), "useTheme"
  end

  # --- extract_definitions: ES module style ---

  def test_detects_export_default_function
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export default function Header() {}"), "Header"
  end

  def test_detects_export_default_class
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export default class Footer {}"), "Footer"
  end

  def test_detects_export_const
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export const StatusBadge = () => {};"),
                    "StatusBadge"
  end

  def test_detects_export_function
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export function IconButton() {}"), "IconButton"
  end

  def test_detects_export_class
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export class DataTable {}"), "DataTable"
  end

  def test_detects_export_const_hook
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export const usePrefetch = () => {};"),
                    "usePrefetch"
  end

  def test_detects_export_function_hook
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("export function useFetch() {}"), "useFetch"
  end

  # --- extract_definitions: deduplication and edge cases ---

  def test_deduplicates_repeated_symbol
    content = "const Foo = 1;\nconst Foo = 2;"
    result = ReactManifest::SymbolExtractor.extract_definitions(content)
    assert_equal 1, result.count("Foo")
  end

  def test_returns_multiple_symbols_from_one_file
    content = "const Foo = 1;\nfunction Bar() {}"
    result = ReactManifest::SymbolExtractor.extract_definitions(content)
    assert_includes result, "Foo"
    assert_includes result, "Bar"
  end

  def test_returns_empty_array_for_empty_string
    assert_equal [], ReactManifest::SymbolExtractor.extract_definitions("")
  end

  def test_returns_empty_array_for_nil
    assert_equal [], ReactManifest::SymbolExtractor.extract_definitions(nil)
  end

  def test_returns_empty_array_for_content_with_only_comments
    content = "// This is a comment\n/* Block comment */\n// Another line"
    assert_equal [], ReactManifest::SymbolExtractor.extract_definitions(content)
  end

  def test_returns_empty_array_for_content_with_only_usages
    content = "<FooBar />\nuseFetch(url)\nmyLib(args)"
    assert_equal [], ReactManifest::SymbolExtractor.extract_definitions(content)
  end

  # --- extract_usages: PascalCase JSX elements ---

  def test_detects_jsx_element_as_usage
    content = "const Page = () => <PrimaryButton />;"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "PrimaryButton"
  end

  def test_detects_jsx_closing_tag_as_usage
    content = "<Modal></Modal>"
    result = ReactManifest::SymbolExtractor.extract_usages(content)
    assert_includes result, "Modal"
  end

  def test_detects_pascal_token_in_ternary
    content = "const el = isActive ? <IconButton /> : null;"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "IconButton"
  end

  def test_detects_pascal_token_passed_as_argument
    content = "render(PrimaryButton);"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "PrimaryButton"
  end

  def test_detects_pascal_token_in_assignment
    content = "const C = PrimaryButton;"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "PrimaryButton"
  end

  def test_detects_pascal_token_in_constructor_call
    content = "const inst = new DataTable({ rows: [] });"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "DataTable"
  end

  # --- extract_usages: use* hooks ---

  def test_detects_hook_call_as_usage
    content = "const data = useFetch('/api');"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "useFetch"
  end

  def test_detects_hook_without_call_parentheses
    content = "const fn = useModal;"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "useModal"
  end

  # --- extract_usages: lowercase lib calls ---

  def test_detects_lowercase_lib_call_as_usage
    content = "const result = formatDate(value);"
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "formatDate"
  end

  # --- extract_usages: JS builtins excluded ---

  def test_excludes_console_from_usages
    content = "console.log('hi');"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "console"
  end

  def test_excludes_document_from_usages
    content = "document.getElementById('app');"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "document"
  end

  def test_excludes_window_from_usages
    content = "window.location.href = '/';"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "window"
  end

  def test_excludes_settimeout_from_usages
    content = "setTimeout(() => {}, 100);"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "setTimeout"
  end

  def test_excludes_parseint_from_usages
    content = "const n = parseInt(str, 10);"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "parseInt"
  end

  def test_excludes_fetch_from_usages
    content = "fetch('/api').then(r => r.json());"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "fetch"
  end

  # --- extract_usages: locally-defined symbols excluded ---

  def test_excludes_locally_defined_pascal_symbol
    content = "const MyWidget = () => <MyWidget />;"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "MyWidget"
  end

  def test_excludes_locally_defined_hook
    content = "function useLocal() {}\nconst x = useLocal();"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "useLocal"
  end

  def test_excludes_locally_defined_pascal_symbol_used_as_lib_prop
    # const-defined PascalCase symbol that also appears in a call expression
    content = "const Wrapper = () => {};\nrender(Wrapper);"
    refute_includes ReactManifest::SymbolExtractor.extract_usages(content), "Wrapper"
  end

  # --- extract_usages: edge cases ---

  def test_extract_usages_returns_empty_for_empty_string
    assert_equal [], ReactManifest::SymbolExtractor.extract_usages("")
  end

  def test_extract_usages_returns_empty_for_nil
    assert_equal [], ReactManifest::SymbolExtractor.extract_usages(nil)
  end

  def test_extract_usages_returns_empty_for_definitions_only
    content = "const Foo = 1;\nfunction Bar() {}\nexport const Baz = () => {};"
    assert_equal [], ReactManifest::SymbolExtractor.extract_usages(content)
  end

  def test_extract_usages_deduplicates_results
    content = "<Foo /><Foo /><Foo />"
    result = ReactManifest::SymbolExtractor.extract_usages(content)
    assert_equal 1, result.count("Foo")
  end
end
