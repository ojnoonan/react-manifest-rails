require "test_helper"

# rubocop:disable Metrics/ClassLength
class ScannerTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @scanner = ReactManifest::Scanner.new(@config)
    @classifier = ReactManifest::TreeClassifier.new(@config)
  end

  def classification
    @classifier.classify
  end

  # --- Phase 1: symbol indexing ---

  def test_indexes_pascal_case_component_symbols_from_components_dir
    result = @scanner.scan(classification)
    assert_includes result.symbol_index.keys, "PrimaryButton"
    assert_includes result.symbol_index.keys, "IconButton"
    assert_includes result.symbol_index.keys, "TextInput"
  end

  def test_indexes_hook_symbols_use_foo_pattern
    result = @scanner.scan(classification)
    assert_includes result.symbol_index.keys, "useFetch"
    assert_includes result.symbol_index.keys, "useModal"
  end

  def test_maps_each_symbol_to_correct_relative_require_path
    result = @scanner.scan(classification)
    assert_match %r{ux/components/buttons/primary_button(\.js\.jsx)?\z}, result.symbol_index["PrimaryButton"]
    assert_match %r{ux/hooks/use_fetch(\.js\.jsx)?\z}, result.symbol_index["useFetch"]
  end

  def test_indexes_es_module_exports_from_shared_files
    result = @scanner.scan(classification)
    assert_includes result.symbol_index.keys, "StatusBadge"
    assert_includes result.symbol_index.keys, "usePrefetch"
    assert result.symbol_index["StatusBadge"].end_with?("ux/components/indicators/status_badge")
    assert result.symbol_index["usePrefetch"].end_with?("ux/hooks/use_prefetch")
  end

  def test_warns_when_duplicate_shared_symbols_are_defined
    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?("Duplicate symbol 'PrimaryButton'") })
  end

  def test_logs_symbol_count_via_rails_logger_debug_when_verbose
    ReactManifest.configure { |c| c.verbose = true }
    Rails.logger.expects(:debug).with { |msg| msg.include?("symbols indexed") }.at_least_once
    @scanner.scan(classification)
  end

  # --- Phase 2: controller usage detection ---

  def test_notifications_controller_detects_use_fetch_usage
    result = @scanner.scan(classification)
    notif_usage = result.controller_usages["notifications"]
    assert(notif_usage.any? { |f| f.include?("use_fetch") })
  end

  def test_notifications_controller_detects_primary_button_jsx_element
    result = @scanner.scan(classification)
    notif_usage = result.controller_usages["notifications"]
    assert(notif_usage.any? { |f| f.include?("primary_button") })
  end

  def test_notifications_controller_detects_use_modal_hook
    result = @scanner.scan(classification)
    notif_usage = result.controller_usages["notifications"]
    assert(notif_usage.any? { |f| f.include?("use_modal") })
  end

  def test_users_controller_detects_text_input_jsx_element
    result = @scanner.scan(classification)
    users_usage = result.controller_usages["users"]
    assert(users_usage.any? { |f| f.include?("text_input") })
  end

  def test_users_controller_detects_primary_button_jsx_element
    result = @scanner.scan(classification)
    users_usage = result.controller_usages["users"]
    assert(users_usage.any? { |f| f.include?("primary_button") })
  end

  def test_products_controller_detects_es_module_component_usage
    result = @scanner.scan(classification)
    products_usage = result.controller_usages["products"]
    assert(products_usage.any? { |f| f.include?("status_badge") })
  end

  def test_products_controller_detects_es_module_hook_usage
    result = @scanner.scan(classification)
    products_usage = result.controller_usages["products"]
    assert(products_usage.any? { |f| f.include?("use_prefetch") })
  end

  def test_usage_lists_are_sorted
    result = @scanner.scan(classification)
    result.controller_usages.each_value do |files|
      assert_equal files.sort, files
    end
  end

  # --- Phase 3: warnings ---

  def test_warns_when_shared_file_is_used_by_many_controllers
    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?("High fan-out") && w.include?("primary_button") })
  end

  def test_detects_component_referenced_as_bare_token_in_ternary
    result = @scanner.scan(classification)
    products_usage = result.controller_usages["products"]
    assert(products_usage.any? { |f| f.include?("icon_button") })
  end

  def test_warns_when_shared_file_references_controller_specific_symbol
    shared_dir = Rails.root.join(@config.ux_root, "components")
    FileUtils.mkdir_p(shared_dir)
    File.write(shared_dir.join("bad_shared.js"),
               "const BadShared = () => <UsersIndex />;\n")

    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js"),
               "const UsersIndex = () => <div />;\n")

    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?("Shared file") && w.include?("UsersIndex") })
  end

  def test_populates_shared_violations_with_structured_data
    shared_dir = Rails.root.join(@config.ux_root, "components")
    FileUtils.mkdir_p(shared_dir)
    File.write(shared_dir.join("bad_shared.js"),
               "const BadShared = () => <UsersIndex />;\n")

    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js"),
               "const UsersIndex = () => <div />;\n")

    result = @scanner.scan(classification)
    violation = result.shared_violations.find { |v| v[:symbol] == "UsersIndex" }
    refute_nil violation
    assert_equal "users", violation[:controller]
    assert violation[:shared_file].include?("bad_shared")
  end

  def test_does_not_warn_when_shared_file_uses_only_shared_symbols
    shared_dir = Rails.root.join(@config.ux_root, "components")
    FileUtils.mkdir_p(shared_dir)
    File.write(shared_dir.join("good_shared.js"),
               "const GoodShared = () => <PrimaryButton />;\n")

    result = @scanner.scan(classification)
    assert(result.warnings.none? { |w| w.include?("GoodShared") })
  end

  def test_does_not_flag_locally_defined_symbols_in_shared_files
    shared_dir = Rails.root.join(@config.ux_root, "components")
    FileUtils.mkdir_p(shared_dir)
    File.write(shared_dir.join("self_ref.js"),
               "const WidgetHelper = () => <div />;\nconst Widget = () => <WidgetHelper />;\n")

    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_index.js"), "const UsersIndex = () => <div />;\n")

    result = @scanner.scan(classification)
    assert(result.warnings.none? { |w| w.include?("WidgetHelper") })
  end

  # --- Token-based symbol detection ---

  def test_detects_pascal_case_component_used_as_constructor
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_search.js"),
               "const search = new PrimaryButton({ fields: ['name'] });\n")

    result = @scanner.scan(classification)
    assert(result.controller_usages["users"].any? { |f| f.include?("primary_button") })
  end

  def test_detects_component_passed_as_bare_function_argument
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_arg.js"), "render(PrimaryButton);\n")

    result = @scanner.scan(classification)
    assert(result.controller_usages["users"].any? { |f| f.include?("primary_button") })
  end

  def test_detects_component_assigned_to_variable
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_assign.js"), "const C = PrimaryButton;\n")

    result = @scanner.scan(classification)
    assert(result.controller_usages["users"].any? { |f| f.include?("primary_button") })
  end

  def test_detects_hook_called_without_jsx_context
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_hook.js"), "const data = useFetch('/api');\n")

    result = @scanner.scan(classification)
    assert(result.controller_usages["users"].any? { |f| f.include?("use_fetch") })
  end

  # --- external_providers ---

  def test_adds_explicit_provider_symbols_to_symbol_index
    ReactManifest.configure { |c| c.external_providers = { "MiniSearch" => "mini-search" } }
    result = @scanner.scan(classification)
    assert_equal "mini-search", result.symbol_index["MiniSearch"]
  end

  def test_detects_constructor_call_against_external_provider
    ReactManifest.configure { |c| c.external_providers = { "MiniSearch" => "mini-search" } }
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_search.js"),
               "const search = new MiniSearch({ fields: ['name'] });\n")

    result = @scanner.scan(classification)
    assert_includes result.controller_usages["users"], "mini-search"
  end

  def test_detects_bare_token_usage_of_external_provider
    ReactManifest.configure { |c| c.external_providers = { "MiniSearch" => "mini-search" } }
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_ms.js"),
               "import MiniSearch from 'minisearch';\nconst s = new MiniSearch({});\n")

    result = @scanner.scan(classification)
    assert_includes result.controller_usages["users"], "mini-search"
  end

  # --- external_roots ---

  def test_indexes_symbols_from_dirs_listed_in_external_roots
    ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
    FileUtils.mkdir_p(ext_dir)
    File.write(ext_dir.join("fancy_widget.js"),
               "const FancyWidget = () => <div />;\n")

    ReactManifest.configure { |c| c.external_roots = [ext_dir.to_s] }

    result = @scanner.scan(classification)
    assert_includes result.symbol_index.keys, "FancyWidget"
  end

  def test_detects_usage_of_symbol_from_external_root
    ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
    FileUtils.mkdir_p(ext_dir)
    File.write(ext_dir.join("fancy_widget.js"),
               "const FancyWidget = () => <div />;\n")

    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("users_fancy.js"),
               "const Page = () => <FancyWidget />;\n")

    ReactManifest.configure { |c| c.external_roots = [ext_dir.to_s] }

    result = @scanner.scan(classification)
    assert(result.controller_usages["users"].any? { |f| f.include?("fancy_widget") })
  end

  def test_warns_when_external_root_file_references_controller_only_symbol
    ext_dir = Rails.root.join("app", "assets", "javascripts", "components", "navbar")
    FileUtils.mkdir_p(ext_dir)
    File.write(ext_dir.join("top_nav.js"),
               "const TopNav = () => <UsersIndex />;\n")

    ReactManifest.configure { |c| c.external_roots = [ext_dir.to_s] }

    result = @scanner.scan(classification)

    refute_empty result.external_violations
    assert(result.warnings.any? { |w| w.include?("External file 'components/navbar/top_nav'") })
    assert(result.warnings.any? { |w| w.include?("uses app-dir symbol 'UsersIndex'") })
  end

  # --- error handling ---

  def test_warns_and_skips_controller_file_deleted_between_glob_and_read
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users").to_s
    victim = File.join(ctrl_dir, "users_index.js")
    File.write(victim, "const X = 1;")

    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path, *args, **opts|
      raise Errno::ENOENT, "No such file" if path == victim && opts == { encoding: "utf-8" }

      original_read.call(path, *args, **opts)
    end

    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?(File.basename(victim)) })
  ensure
    begin
      File.singleton_class.remove_method(:read)
    rescue StandardError
      nil
    end
  end

  def test_warns_and_skips_controller_file_with_permission_error
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users").to_s
    victim = File.join(ctrl_dir, "users_index.js")
    File.write(victim, "const X = 1;")

    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path, *args, **opts|
      raise Errno::EACCES, "Permission denied" if path == victim && opts == { encoding: "utf-8" }

      original_read.call(path, *args, **opts)
    end

    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?(File.basename(victim)) })
  ensure
    begin
      File.singleton_class.remove_method(:read)
    rescue StandardError
      nil
    end
  end

  def test_warns_and_skips_non_utf8_controller_file
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users").to_s
    victim = File.join(ctrl_dir, "users_index.js")
    File.write(victim, "const X = 1;")

    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path, *args, **opts|
      raise Encoding::InvalidByteSequenceError, "invalid byte" if path == victim && opts == { encoding: "utf-8" }

      original_read.call(path, *args, **opts)
    end

    result = @scanner.scan(classification)
    assert(result.warnings.any? { |w| w.include?(File.basename(victim)) })
  ensure
    begin
      File.singleton_class.remove_method(:read)
    rescue StandardError
      nil
    end
  end

  def test_returns_empty_symbols_for_unreadable_shared_file
    shared_file = Rails.root.join(@config.ux_root, "components", "buttons", "primary_button.jsx").to_s

    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path, *args, **opts|
      raise Errno::EACCES, "Permission denied" if path == shared_file && opts == { encoding: "utf-8" }

      original_read.call(path, *args, **opts)
    end

    result = @scanner.scan(classification)
    assert_kind_of ReactManifest::Scanner::Result, result
  ensure
    begin
      File.singleton_class.remove_method(:read)
    rescue StandardError
      nil
    end
  end

  def test_does_not_crash_on_invalid_empty_js_content
    ctrl_dir = Rails.root.join(@config.ux_root, "app", "users").to_s
    junk_file = File.join(ctrl_dir, "users_junk.js")
    File.write(junk_file, "\x00\x01\x02 not js !!!")

    assert_silent { @scanner.scan(classification) }
  end

  # --- single traversal ---

  def test_visits_each_controller_dir_exactly_once_per_scan
    call_count = Hash.new(0)
    original_js_files = @scanner.method(:js_files_in)
    @scanner.define_singleton_method(:js_files_in) do |dir|
      call_count[dir] += 1
      original_js_files.call(dir)
    end

    cls = classification
    @scanner.scan(cls)

    cls.controller_dirs.each do |ctrl|
      count = call_count[ctrl[:path]]
      assert_equal 1, count, "Expected #{ctrl[:path]} traversed once, got #{count}"
    end
  ensure
    begin
      @scanner.singleton_class.remove_method(:js_files_in)
    rescue StandardError
      nil
    end
  end

  def test_does_not_re_read_shared_files_during_violation_detection
    read_count = Hash.new(0)
    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path, *args, **opts|
      rel = path.to_s.sub("#{Rails.root}/", "")
      read_count[rel] += 1 if rel.start_with?("app/assets/javascripts/ux/")
      original_read.call(path, *args, **opts)
    end

    @scanner.scan(classification)

    read_count.each do |file, count|
      assert_equal 1, count, "Expected #{file} to be read once, got #{count}"
    end
  ensure
    begin
      File.singleton_class.remove_method(:read)
    rescue StandardError
      nil
    end
  end

  # --- symbol index caching ---

  def test_exposes_empty_file_symbol_cache_after_reset
    ReactManifest.reset!
    assert_empty ReactManifest::Scanner.file_symbol_cache
  end

  def test_populates_file_symbol_cache_after_scanning_shared_files
    @scanner.scan(classification)
    refute_empty ReactManifest::Scanner.file_symbol_cache
  end

  def test_does_not_re_read_shared_files_on_repeated_scan
    @scanner.scan(classification)
    @scanner.expects(:scan_file_definitions).never
    @scanner.scan(classification)
  end

  def test_clears_file_symbol_cache_on_reset
    @scanner.scan(classification)
    refute_empty ReactManifest::Scanner.file_symbol_cache

    ReactManifest.reset!
    assert_empty ReactManifest::Scanner.file_symbol_cache
  end

  def test_rescans_only_invalidated_file_leaving_others_cached
    @scanner.scan(classification)

    target_file = ReactManifest::Scanner.file_symbol_cache.keys.first
    ReactManifest::Scanner.invalidate(target_file)

    rescanned = []
    original_parse = @scanner.method(:parse_definitions)
    @scanner.define_singleton_method(:parse_definitions) do |content|
      rescanned << content
      original_parse.call(content)
    end

    @scanner.scan(classification)

    assert_equal 1, rescanned.size
  ensure
    begin
      @scanner.singleton_class.remove_method(:parse_definitions)
    rescue StandardError
      nil
    end
  end

  def test_produces_same_symbol_index_after_partial_cache_invalidation
    result_before = @scanner.scan(classification)

    target_file = ReactManifest::Scanner.file_symbol_cache.keys.first
    ReactManifest::Scanner.invalidate(target_file)

    result_after = @scanner.scan(classification)
    assert_equal result_before.symbol_index, result_after.symbol_index
  end

  # --- TypeScript extension handling ---

  def test_indexes_ts_shared_file_with_clean_require_path
    ReactManifest.configure { |c| c.extensions = %w[js jsx ts tsx] }
    components_dir = Rails.root.join(@config.ux_root, "components")
    File.write(File.join(components_dir, "ts_util.ts"), "export const TsUtil = () => {};\n")

    result = @scanner.scan(@classifier.classify)
    assert_equal "ux/components/ts_util", result.symbol_index["TsUtil"]
  end

  def test_indexes_tsx_shared_file_with_clean_require_path
    ReactManifest.configure { |c| c.extensions = %w[js jsx ts tsx] }
    components_dir = Rails.root.join(@config.ux_root, "components")
    File.write(File.join(components_dir, "tsx_card.tsx"), "export const TsxCard = () => <div />;\n")

    result = @scanner.scan(@classifier.classify)
    assert_equal "ux/components/tsx_card", result.symbol_index["TsxCard"]
  end
end
# rubocop:enable Metrics/ClassLength
