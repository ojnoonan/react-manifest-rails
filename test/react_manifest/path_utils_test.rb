require "test_helper"
require "react_manifest/path_utils"

class PathUtilsTest < Minitest::Test
  def setup
    @host = Class.new { include ReactManifest::PathUtils }.new
  end

  def test_strips_js_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.js")
  end

  def test_strips_jsx_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.jsx")
  end

  def test_strips_js_jsx_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.js.jsx")
  end

  def test_strips_ts_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.ts")
  end

  def test_strips_tsx_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.tsx")
  end

  def test_strips_ts_tsx_extension
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo.ts.tsx")
  end

  def test_strips_nothing_from_extensionless_path
    assert_equal "ux/components/foo", @host.strip_asset_extension("ux/components/foo")
  end

  def test_preserves_non_asset_extension_like_css
    assert_equal "ux/components/foo.css", @host.strip_asset_extension("ux/components/foo.css")
  end
end
