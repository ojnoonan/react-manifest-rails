module ReactManifest
  module PathUtils
    # Matches compound and single Sprockets-understood asset extensions.
    # Order is significant: compound forms must precede their singles.
    STRIPPABLE_EXTENSIONS = /\.(ts\.tsx|js\.jsx|tsx|ts|jsx|js)$/

    def strip_asset_extension(path)
      path.to_s.sub(STRIPPABLE_EXTENSIONS, "")
    end
  end
end
