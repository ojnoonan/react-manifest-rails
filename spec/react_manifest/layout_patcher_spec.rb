require "spec_helper"

RSpec.describe ReactManifest::LayoutPatcher do
  subject(:patcher) { described_class.new(config) }

  let(:config) { ReactManifest.configuration }

  around(:each) do |example|
    with_temp_rails_root do |tmpdir|
      copy_fixtures_to(tmpdir)
      fixture_config(tmpdir)
      example.run
    end
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

  describe "#patch!" do
    context "ERB layout" do
      it "inserts react_bundle_tag after javascript_include_tag" do
        patcher.patch!
        content = read_layout("application.html.erb")
        lines = content.lines
        js_idx  = lines.index { |l| l.include?("javascript_include_tag") }
        next_ln = lines[js_idx + 1]
        expect(next_ln).to include("react_bundle_tag")
      end

      it "uses ERB syntax" do
        patcher.patch!
        content = read_layout("application.html.erb")
        expect(content).to include("<%= react_bundle_tag")
      end

      it "preserves the indentation of javascript_include_tag" do
        patcher.patch!
        content = read_layout("application.html.erb")
        lines = content.lines
        js_idx     = lines.index { |l| l.include?("javascript_include_tag") }
        js_indent  = lines[js_idx][/^\s*/]
        rbt_indent = lines[js_idx + 1][/^\s*/]
        expect(rbt_indent).to eq(js_indent)
      end

      it "returns status :patched" do
        results = patcher.patch!
        erb_result = results.find { |r| r.file.end_with?(".erb") }
        expect(erb_result.status).to eq(:patched)
      end
    end

    context "HAML layout" do
      it "inserts react_bundle_tag after javascript_include_tag" do
        patcher.patch!
        content = read_layout("application.html.haml")
        lines = content.lines
        js_idx  = lines.index { |l| l.include?("javascript_include_tag") }
        next_ln = lines[js_idx + 1]
        expect(next_ln).to include("react_bundle_tag")
      end

      it "uses HAML syntax (= not <%=)" do
        patcher.patch!
        content = read_layout("application.html.haml")
        expect(content).not_to include("<%=")
        expect(content).to match(/^\s+= react_bundle_tag/)
      end

      it "returns status :patched" do
        results = patcher.patch!
        haml_result = results.find { |r| r.file.end_with?(".haml") }
        expect(haml_result.status).to eq(:patched)
      end
    end

    context "already patched layout" do
      before do
        path = layout_path("application.html.erb")
        File.write(path, "#{File.read(path)}\n<%= react_bundle_tag %>\n")
      end

      it "returns status :already_patched and does not duplicate" do
        results = patcher.patch!
        erb_result = results.find { |r| r.file.end_with?(".erb") }
        expect(erb_result.status).to eq(:already_patched)

        content = read_layout("application.html.erb")
        expect(content.scan("react_bundle_tag").size).to eq(1)
      end
    end

    context "layout with no javascript_include_tag but has </head>" do
      before do
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
      end

      it "inserts react_bundle_tag before </head>" do
        patcher.patch!
        content = read_layout("application.html.erb")
        lines = content.lines
        head_close_idx = lines.rindex { |l| l.include?("</head>") }
        # tag should appear on the line just before </head>
        before_head = lines[head_close_idx - 1]
        expect(before_head).to include("react_bundle_tag")
      end

      it "returns status :patched" do
        results = patcher.patch!
        erb_result = results.find { |r| r.file.end_with?(".erb") }
        expect(erb_result.status).to eq(:patched)
      end
    end

    context "layout with no recognisable injection point" do
      before do
        path = layout_path("application.html.erb")
        File.write(path, "<html><body>plain</body></html>")
      end

      it "returns status :no_injection_point" do
        results = patcher.patch!
        erb_result = results.find { |r| r.file.end_with?(".erb") }
        expect(erb_result.status).to eq(:no_injection_point)
      end

      it "does not modify the file" do
        original = read_layout("application.html.erb")
        patcher.patch!
        expect(read_layout("application.html.erb")).to eq(original)
      end
    end

    context "dry_run mode" do
      before { ReactManifest.configure { |c| c.dry_run = true } }

      it "returns status :dry_run" do
        results = described_class.new(config).patch!
        expect(results.map(&:status)).to all(satisfy { |s| %i[dry_run already_patched no_injection_point].include?(s) })
      end

      it "does not modify any layout file" do
        originals = {
          "application.html.erb" => read_layout("application.html.erb"),
          "application.html.haml" => read_layout("application.html.haml")
        }
        described_class.new(config).patch!
        originals.each do |name, original|
          expect(read_layout(name)).to eq(original)
        end
      end
    end

    context "when no layouts directory exists" do
      before { FileUtils.rm_rf(Rails.root.join("app", "views", "layouts").to_s) }

      it "returns an empty array" do
        result = patcher.patch!
        expect(result).to eq([])
      end
    end
  end
end
