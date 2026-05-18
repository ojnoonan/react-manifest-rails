require "test_helper"

class SymbolExtractorTest < Minitest::Test
  def test_extract_definitions_detects_commonjs_style_symbols
    content = <<~JS
      const PrimaryButton = () => {};
      let SecondaryButton = function() {};
      var FormPanel = {};
      function StatusBadge() {}
      class ProfileCard extends React.Component {}
      const useFetch = () => {};
      function useModal() {}
    JS

    assert_equal %w[
      PrimaryButton
      SecondaryButton
      FormPanel
      StatusBadge
      ProfileCard
      useFetch
      useModal
    ], ReactManifest::SymbolExtractor.extract_definitions(content)
  end

  def test_extract_definitions_detects_es_module_symbols
    content = <<~JS
      export default function AccountMenu() {}
      export default class DrawerPanel {}
      export const ToastMessage = () => {};
      export let FilterPanel = {};
      export var ResultCard = {};
      export const usePagination = () => {};
      export function usePermissions() {}
      export function EmptyState() {}
      export class PageHeader extends React.Component {}
    JS

    expected = %w[
      AccountMenu
      DrawerPanel
      ToastMessage
      FilterPanel
      ResultCard
      usePagination
      usePermissions
      EmptyState
      PageHeader
    ]
    assert_equal expected.sort, ReactManifest::SymbolExtractor.extract_definitions(content).sort
  end

  def test_extract_definitions_deduplicates_symbols
    content = <<~JS
      const PrimaryButton = () => {};
      function PrimaryButton() {}
      export const PrimaryButton = () => {};
    JS

    assert_equal ["PrimaryButton"], ReactManifest::SymbolExtractor.extract_definitions(content)
  end

  def test_extract_usages_detects_components_hooks_and_lib_calls
    content = <<~JS
      const orderDate = formatDate(order.createdAt);
      const plural = pluralizeWords(count, "item");
      const modal = useModal();
      const link = <PrimaryButton icon={StatusBadge} />;
      const panel = new DrawerPanel();
    JS

    assert_equal %w[
      PrimaryButton
      StatusBadge
      DrawerPanel
      useModal
      formatDate
      pluralizeWords
    ], ReactManifest::SymbolExtractor.extract_usages(content)
  end

  def test_extract_usages_excludes_js_builtins
    content = <<~JS
      console.log(document.title);
      window.setTimeout(function() {}, 10);
      setTimeout(() => {}, 10);
      parseInt(value, 10);
      JSON.stringify(Object.assign({}, payload));
      Promise.resolve(Array.from(items));
    JS

    assert_empty ReactManifest::SymbolExtractor.extract_usages(content)
  end

  def test_extract_usages_excludes_locally_defined_symbols
    content = <<~JS
      const LocalPanel = () => <SharedPanel />;
      function useLocalThing() {}
      class LocalClass {}
      const result = <LocalPanel extra={SharedBadge} />;
      useLocalThing();
      useSharedThing();
    JS

    assert_equal %w[
      SharedPanel
      SharedBadge
      useSharedThing
    ], ReactManifest::SymbolExtractor.extract_usages(content)
  end

  def test_extract_methods_handle_edge_cases_without_file_io
    assert_empty ReactManifest::SymbolExtractor.extract_definitions("")
    assert_empty ReactManifest::SymbolExtractor.extract_usages("")

    comments_only = <<~JS
      // <CommentedPanel />
      /*
       * useCommentedHook();
       * formatDate();
       */
    JS
    assert_empty ReactManifest::SymbolExtractor.extract_definitions(comments_only)
    assert_empty ReactManifest::SymbolExtractor.extract_usages(comments_only)

    definitions_only = <<~JS
      const PrimaryButton = () => {};
      export function useModal() {}
    JS
    assert_empty ReactManifest::SymbolExtractor.extract_usages(definitions_only)
  end
end
