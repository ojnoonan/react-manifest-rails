require "spec_helper"

RSpec.describe ReactManifest::ApplicationAnalyzer do
  subject(:analyzer) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
  end

  describe "#analyze" do
    it "finds application.js and application_dev.js" do
      results = analyzer.analyze
      filenames = results.map { |r| File.basename(r.file) }
      expect(filenames).to include("application.js", "application_dev.js")
    end

    describe "application.js classification" do
      subject(:result) { analyzer.analyze.find { |r| r.file.end_with?("application.js") } }

      it "classifies react/ requires as vendor (keep)" do
        vendor = result.vendor_lines.map(&:path)
        expect(vendor).to include("react/react.min", "react/react-dom.min", "react/mui.min")
      end

      it "classifies require_tree ./ux as ux_code (remove)" do
        ux_lines = result.ux_code_lines
        expect(ux_lines).not_to be_empty
        expect(ux_lines.any? { |l| l.directive.include?("tree") }).to be true
      end

      it "is NOT clean (has ux_code to remove)" do
        expect(result.clean?).to be false
      end
    end

    describe "a clean application.js (vendor-only)" do
      it "reports clean? true when only vendor requires remain" do
        clean_content = "//= require react/react.min\n//= require react/react-dom.min\n"
        path = File.join(config.abs_output_dir, "application_clean.js")
        File.write(path, clean_content)

        # Re-analyze to pick up the new file
        results = analyzer.analyze
        clean_result = results.find { |r| r.file.end_with?("application_clean.js") }
        expect(clean_result.clean?).to be true
      end
    end
  end
end
