require "spec_helper"
require "react_manifest/path_utils"

RSpec.describe ReactManifest::PathUtils do
  let(:host) do
    Class.new { include ReactManifest::PathUtils }.new
  end

  describe "#strip_asset_extension" do
    {
      "ux/components/foo.js" => "ux/components/foo",
      "ux/components/foo.jsx" => "ux/components/foo",
      "ux/components/foo.js.jsx" => "ux/components/foo",
      "ux/components/foo.ts" => "ux/components/foo",
      "ux/components/foo.tsx" => "ux/components/foo",
      "ux/components/foo.ts.tsx" => "ux/components/foo",
      "ux/components/foo" => "ux/components/foo",
      "ux/components/foo.css" => "ux/components/foo.css"
    }.each do |input, expected|
      ext  = File.extname(input)
      desc = ext.empty? ? "nothing from #{input.split('/').last}" : "#{ext} from #{input.split('/').last}"
      it "strips #{desc}" do
        expect(host.strip_asset_extension(input)).to eq(expected)
      end
    end
  end
end
