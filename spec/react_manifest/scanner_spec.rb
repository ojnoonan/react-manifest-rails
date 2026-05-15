require "spec_helper"

RSpec.describe ReactManifest::Scanner do
  subject(:scanner) { described_class.new(config) }

  let(:config)     { ReactManifest.configuration }
  let(:classifier) { ReactManifest::TreeClassifier.new(config) }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  describe "Phase 1: symbol indexing" do
    let(:result) { scanner.scan(classifier.classify) }

    it "indexes PascalCase component symbols from components/" do
      expect(result.symbol_index.keys).to include("PrimaryButton", "IconButton", "TextInput")
    end

    it "indexes hook symbols (useFoo pattern)" do
      expect(result.symbol_index.keys).to include("useFetch", "useModal")
    end

    it "maps each symbol to its correct relative require path" do
      expect(result.symbol_index["PrimaryButton"]).to match(%r{ux/components/buttons/primary_button(\.js\.jsx)?\z})
      expect(result.symbol_index["useFetch"]).to match(%r{ux/hooks/use_fetch(\.js\.jsx)?\z})
    end

    it "indexes ES module exports from shared files" do
      expect(result.symbol_index.keys).to include("StatusBadge", "usePrefetch")
      expect(result.symbol_index["StatusBadge"]).to end_with("ux/components/indicators/status_badge")
      expect(result.symbol_index["usePrefetch"]).to end_with("ux/hooks/use_prefetch")
    end

    it "warns when duplicate shared symbols are defined" do
      expect(result.warnings.any? { |w| w.include?("Duplicate symbol 'PrimaryButton'") }).to be true
    end

    it "logs symbol count via Rails.logger.debug when verbose" do
      ReactManifest.configure { |c| c.verbose = true }
      allow(Rails.logger).to receive(:debug)
      scanner.scan(classifier.classify)
      expect(Rails.logger).to have_received(:debug).with(a_string_including("symbols indexed"))
    end
  end

  describe "Phase 2: controller usage detection" do
    let(:result) { scanner.scan(classifier.classify) }

    context "notifications controller" do
      let(:notif_usage) { result.controller_usages["notifications"] }

      it "detects useFetch usage" do
        expect(notif_usage.any? { |f| f.include?("use_fetch") }).to be true
      end
    end

    context "notifications_show (PrimaryButton + useModal + formatDate)" do
      let(:notif_usage) { result.controller_usages["notifications"] }

      it "detects PrimaryButton JSX element" do
        expect(notif_usage.any? { |f| f.include?("primary_button") }).to be true
      end

      it "detects useModal hook" do
        expect(notif_usage.any? { |f| f.include?("use_modal") }).to be true
      end
    end

    context "users controller" do
      let(:users_usage) { result.controller_usages["users"] }

      it "detects TextInput JSX element" do
        expect(users_usage.any? { |f| f.include?("text_input") }).to be true
      end

      it "detects PrimaryButton JSX element" do
        expect(users_usage.any? { |f| f.include?("primary_button") }).to be true
      end
    end

    context "products controller" do
      let(:products_usage) { result.controller_usages["products"] }

      it "detects ES module component usage" do
        expect(products_usage.any? { |f| f.include?("status_badge") }).to be true
      end

      it "detects ES module hook usage" do
        expect(products_usage.any? { |f| f.include?("use_prefetch") }).to be true
      end
    end

    it "usage lists are sorted" do
      result.controller_usages.each_value do |files|
        expect(files).to eq(files.sort)
      end
    end
  end

  describe "Phase 3: warnings" do
    it "warns when a shared file is used by many controllers" do
      result = scanner.scan(classifier.classify)
      expect(result.warnings.any? { |w| w.include?("High fan-out") && w.include?("primary_button") }).to be true
    end

    it "detects a component referenced as a bare token in a ternary expression" do
      result = scanner.scan(classifier.classify)
      products_usage = result.controller_usages["products"]
      # IconButton appears as a bare token in `props.useAltButton ? IconButton : PrimaryButton`
      # Token-based matching picks it up correctly.
      expect(products_usage.any? { |f| f.include?("icon_button") }).to be true
    end

    describe "shared-file uses app-dir symbol detection" do
      it "warns when a shared file references a controller-specific symbol" do
        shared_dir = Rails.root.join(config.ux_root, "components")
        FileUtils.mkdir_p(shared_dir)
        File.write(shared_dir.join("bad_shared.js"),
                   "const BadShared = () => <UsersIndex />;\n")

        ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js"),
                   "const UsersIndex = () => <div />;\n")

        result = scanner.scan(classifier.classify)
        expect(result.warnings.any? { |w| w.include?("Shared file") && w.include?("UsersIndex") }).to be true
      end

      it "populates shared_violations with structured data" do
        shared_dir = Rails.root.join(config.ux_root, "components")
        FileUtils.mkdir_p(shared_dir)
        File.write(shared_dir.join("bad_shared.js"),
                   "const BadShared = () => <UsersIndex />;\n")

        ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js"),
                   "const UsersIndex = () => <div />;\n")

        result = scanner.scan(classifier.classify)
        violation = result.shared_violations.find { |v| v[:symbol] == "UsersIndex" }
        expect(violation).not_to be_nil
        expect(violation[:controller]).to eq("users")
        expect(violation[:shared_file]).to include("bad_shared")
      end

      it "does not warn when a shared file only uses other shared symbols" do
        shared_dir = Rails.root.join(config.ux_root, "components")
        FileUtils.mkdir_p(shared_dir)
        File.write(shared_dir.join("good_shared.js"),
                   "const GoodShared = () => <PrimaryButton />;\n")

        result = scanner.scan(classifier.classify)
        expect(result.warnings.none? { |w| w.include?("GoodShared") }).to be true
      end

      it "does not flag locally-defined symbols in shared files" do
        shared_dir = Rails.root.join(config.ux_root, "components")
        FileUtils.mkdir_p(shared_dir)
        # Defines and uses WidgetHelper locally — not a cross-boundary violation
        File.write(shared_dir.join("self_ref.js"),
                   "const WidgetHelper = () => <div />;\nconst Widget = () => <WidgetHelper />;\n")

        ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
        FileUtils.mkdir_p(ctrl_dir)
        File.write(ctrl_dir.join("users_index.js"), "const UsersIndex = () => <div />;\n")

        result = scanner.scan(classifier.classify)
        expect(result.warnings.none? { |w| w.include?("WidgetHelper") }).to be true
      end
    end
  end

  describe "token-based symbol detection" do
    # These specs verify that components/hooks/libs are detected via plain identifier
    # token matching — not just JSX-tag or prop-specific patterns.

    it "detects a PascalCase component used as a constructor (new ClassName(...))" do
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_search.js"),
                 "const search = new PrimaryButton({ fields: ['name'] });\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"].any? { |f| f.include?("primary_button") }).to be true
    end

    it "detects a component passed as a bare function argument" do
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_arg.js"),
                 "render(PrimaryButton);\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"].any? { |f| f.include?("primary_button") }).to be true
    end

    it "detects a component assigned to a variable (not JSX)" do
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_assign.js"),
                 "const C = PrimaryButton;\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"].any? { |f| f.include?("primary_button") }).to be true
    end

    it "detects a hook called without JSX context" do
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_hook.js"),
                 "const data = useFetch('/api');\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"].any? { |f| f.include?("use_fetch") }).to be true
    end
  end

  describe "external_providers" do
    it "adds explicit provider symbols to the symbol index" do
      ReactManifest.configure do |c|
        c.external_providers = { "MiniSearch" => "mini-search" }
      end
      result = scanner.scan(classifier.classify)
      expect(result.symbol_index["MiniSearch"]).to eq("mini-search")
    end

    it "detects a constructor call against an external provider" do
      ReactManifest.configure do |c|
        c.external_providers = { "MiniSearch" => "mini-search" }
      end
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_search.js"),
                 "const search = new MiniSearch({ fields: ['name'] });\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"]).to include("mini-search")
    end

    it "detects bare token usage of an external provider" do
      ReactManifest.configure do |c|
        c.external_providers = { "MiniSearch" => "mini-search" }
      end
      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_ms.js"),
                 "import MiniSearch from 'minisearch';\nconst s = new MiniSearch({});\n")

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"]).to include("mini-search")
    end
  end

  describe "external_roots" do
    it "indexes symbols from dirs listed in external_roots" do
      ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
      FileUtils.mkdir_p(ext_dir)
      File.write(ext_dir.join("fancy_widget.js"),
                 "const FancyWidget = () => <div />;\n")

      ReactManifest.configure do |c|
        c.external_roots = [ext_dir.to_s]
      end

      result = scanner.scan(classifier.classify)
      expect(result.symbol_index.keys).to include("FancyWidget")
    end

    it "detects usage of a symbol from an external root" do
      ext_dir = Rails.root.join("app", "assets", "javascripts", "ext_components")
      FileUtils.mkdir_p(ext_dir)
      File.write(ext_dir.join("fancy_widget.js"),
                 "const FancyWidget = () => <div />;\n")

      ctrl_dir = Rails.root.join(config.ux_root, "app", "users")
      FileUtils.mkdir_p(ctrl_dir)
      File.write(ctrl_dir.join("users_fancy.js"),
                 "const Page = () => <FancyWidget />;\n")

      ReactManifest.configure do |c|
        c.external_roots = [ext_dir.to_s]
      end

      result = scanner.scan(classifier.classify)
      expect(result.controller_usages["users"].any? { |f| f.include?("fancy_widget") }).to be true
    end

    it "warns when an external root file references a controller-only ux/app symbol" do
      ext_dir = Rails.root.join("app", "assets", "javascripts", "components", "navbar")
      FileUtils.mkdir_p(ext_dir)
      File.write(ext_dir.join("top_nav.js"),
                 "const TopNav = () => <UsersIndex />;\n")

      ReactManifest.configure do |c|
        c.external_roots = [ext_dir.to_s]
      end

      result = scanner.scan(classifier.classify)

      expect(result.external_violations).not_to be_empty
      expect(result.warnings.any? { |w| w.include?("External file 'components/navbar/top_nav'") }).to be true
      expect(result.warnings.any? { |w| w.include?("uses app-dir symbol 'UsersIndex'") }).to be true
    end
  end

  describe "error handling" do
    it "warns and skips a controller file deleted between glob and read" do
      ctrl_dir = File.join(Rails.root.join(config.ux_root, "app", "users").to_s)
      victim   = File.join(ctrl_dir, "users_index.js")
      File.write(victim, "const X = 1;")

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(victim, encoding: "utf-8")
                                   .and_raise(Errno::ENOENT, "No such file")

      result = scanner.scan(classifier.classify)
      expect(result.warnings.any? { |w| w.include?(File.basename(victim)) }).to be true
    end

    it "warns and skips a controller file with a permission error" do
      ctrl_dir = File.join(Rails.root.join(config.ux_root, "app", "users").to_s)
      victim   = File.join(ctrl_dir, "users_index.js")
      File.write(victim, "const X = 1;")

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(victim, encoding: "utf-8")
                                   .and_raise(Errno::EACCES, "Permission denied")

      result = scanner.scan(classifier.classify)
      expect(result.warnings.any? { |w| w.include?(File.basename(victim)) }).to be true
    end

    it "warns and skips a non-UTF-8 controller file" do
      ctrl_dir = File.join(Rails.root.join(config.ux_root, "app", "users").to_s)
      victim   = File.join(ctrl_dir, "users_index.js")
      File.write(victim, "const X = 1;")

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(victim, encoding: "utf-8")
                                   .and_raise(Encoding::InvalidByteSequenceError, "invalid byte")

      result = scanner.scan(classifier.classify)
      expect(result.warnings.any? { |w| w.include?(File.basename(victim)) }).to be true
    end

    it "returns empty symbols for an unreadable shared file" do
      shared_file = File.join(Rails.root.join(config.ux_root, "components", "buttons", "primary_button.jsx").to_s)

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(shared_file, encoding: "utf-8")
                                   .and_raise(Errno::EACCES, "Permission denied")

      result = scanner.scan(classifier.classify)
      # Should not raise; symbol index may be smaller but scan completes
      expect(result).to be_a(ReactManifest::Scanner::Result)
    end

    it "does not crash on invalid/empty JS content" do
      ctrl_dir = File.join(Rails.root.join(config.ux_root, "app", "users").to_s)
      junk_file = File.join(ctrl_dir, "users_junk.js")
      File.write(junk_file, "\x00\x01\x02 not js !!!")

      expect { scanner.scan(classifier.classify) }.not_to raise_error
    end
  end

  describe "single traversal" do
    let(:classification) { classifier.classify }

    it "visits each controller dir exactly once per scan" do
      call_count = Hash.new(0)
      allow(scanner).to receive(:js_files_in).and_wrap_original do |m, dir|
        call_count[dir] += 1
        m.call(dir)
      end

      scanner.scan(classification)

      classification.controller_dirs.each do |ctrl|
        count = call_count[ctrl[:path]]
        expect(count).to eq(1), "Expected #{ctrl[:path]} traversed once, got #{count}"
      end
    end

    it "does not re-read shared files during violation detection" do
      read_count = Hash.new(0)
      allow(File).to receive(:read).and_wrap_original do |m, path, **opts|
        rel = path.to_s.sub("#{Rails.root}/", "")
        read_count[rel] += 1 if rel.start_with?("app/assets/javascripts/ux/")
        m.call(path, **opts)
      end

      scanner.scan(classification)

      read_count.each do |file, count|
        expect(count).to eq(1), "Expected #{file} to be read once, got #{count}"
      end
    end
  end

  describe "symbol index caching" do
    let(:classification) { classifier.classify }

    it "exposes an empty file_symbol_cache after reset!" do
      ReactManifest.reset!
      expect(ReactManifest::Scanner.file_symbol_cache).to be_empty
    end

    it "populates the file symbol cache after scanning shared files" do
      scanner.scan(classification)
      expect(ReactManifest::Scanner.file_symbol_cache).not_to be_empty
    end

    it "does not re-read shared files on a repeated scan" do
      scanner.scan(classification)

      expect(scanner).not_to receive(:scan_file_definitions)
      scanner.scan(classification)
    end

    it "clears the file symbol cache on ReactManifest.reset!" do
      scanner.scan(classification)
      expect(ReactManifest::Scanner.file_symbol_cache).not_to be_empty

      ReactManifest.reset!
      expect(ReactManifest::Scanner.file_symbol_cache).to be_empty
    end

    it "rescans only the invalidated file, leaving all others cached" do
      scanner.scan(classification)

      target_file = ReactManifest::Scanner.file_symbol_cache.keys.first
      ReactManifest::Scanner.invalidate(target_file)

      rescanned = []
      allow(scanner).to receive(:parse_definitions).and_wrap_original do |m, content|
        rescanned << content
        m.call(content)
      end

      scanner.scan(classification)

      expect(rescanned.size).to eq(1)
    end

    it "produces the same symbol index after a partial cache invalidation" do
      result_before = scanner.scan(classification)

      target_file = ReactManifest::Scanner.file_symbol_cache.keys.first
      ReactManifest::Scanner.invalidate(target_file)

      result_after = scanner.scan(classification)
      expect(result_after.symbol_index).to eq(result_before.symbol_index)
    end
  end

  describe "TypeScript extension handling" do
    before do
      ReactManifest.configure do |c|
        c.extensions = %w[js jsx ts tsx]
      end
    end

    it "indexes a .ts shared file with a clean require path (no .ts suffix)" do
      components_dir = Rails.root.join(config.ux_root, "components")
      File.write(File.join(components_dir, "ts_util.ts"), "export const TsUtil = () => {};\n")

      result = scanner.scan(classifier.classify)
      expect(result.symbol_index["TsUtil"]).to eq("ux/components/ts_util")
    end

    it "indexes a .tsx shared file with a clean require path (no .tsx suffix)" do
      components_dir = Rails.root.join(config.ux_root, "components")
      File.write(File.join(components_dir, "tsx_card.tsx"), "export const TsxCard = () => <div />;\n")

      result = scanner.scan(classifier.classify)
      expect(result.symbol_index["TsxCard"]).to eq("ux/components/tsx_card")
    end
  end
end
