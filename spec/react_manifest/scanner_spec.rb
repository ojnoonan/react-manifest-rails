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

    it "indexes lowercase lib functions" do
      expect(result.symbol_index.keys).to include("formatDate", "apiPost", "apiGet")
    end

    it "maps each symbol to its correct relative require path" do
      expect(result.symbol_index["PrimaryButton"]).to match(%r{ux/components/buttons/primary_button(\.js\.jsx)?\z})
      expect(result.symbol_index["useFetch"]).to match(%r{ux/hooks/use_fetch(\.js\.jsx)?\z})
      expect(result.symbol_index["formatDate"]).to match(%r{ux/lib/format_date(\.js\.jsx)?\z})
    end

    it "indexes ES module exports from shared files" do
      expect(result.symbol_index.keys).to include("StatusBadge", "usePrefetch", "pluralizeWords")
      expect(result.symbol_index["StatusBadge"]).to end_with("ux/components/indicators/status_badge")
      expect(result.symbol_index["usePrefetch"]).to end_with("ux/hooks/use_prefetch")
      expect(result.symbol_index["pluralizeWords"]).to end_with("ux/lib/pluralize_words")
    end

    it "warns when duplicate shared symbols are defined" do
      expect(result.warnings.any? { |w| w.include?("Duplicate symbol 'PrimaryButton'") }).to be true
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

      it "detects formatDate lib call" do
        expect(notif_usage.any? { |f| f.include?("format_date") }).to be true
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

      it "detects ES module lib function usage" do
        expect(products_usage.any? { |f| f.include?("pluralize_words") }).to be true
      end
    end

    it "usage lists are sorted" do
      result.controller_usages.each_value do |files|
        expect(files).to eq(files.sort)
      end
    end
  end

  describe "Phase 3: warnings" do
    it "warns about files not matching <controller>_*.js.jsx naming convention" do
      # Write a mis-named file
      bad_file = File.join(Rails.root.join(config.ux_root, "app", "users").to_s, "index.js.jsx")
      File.write(bad_file, "// bad name")

      result = scanner.scan(classifier.classify)
      expect(result.warnings.any? { |w| w.include?("naming convention") }).to be true
    end

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
end
