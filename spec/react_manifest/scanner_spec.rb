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
      expect(result.symbol_index["PrimaryButton"]).to end_with("ux/components/buttons/primary_button")
      expect(result.symbol_index["useFetch"]).to end_with("ux/hooks/use_fetch")
      expect(result.symbol_index["formatDate"]).to end_with("ux/lib/format_date")
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
