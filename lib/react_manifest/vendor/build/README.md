# Build source for ast_extractor.js

`../ast_extractor.js` is a pre-built, committed bundle (Acorn + acorn-jsx +
our own extraction logic) — it is NOT built at gem install or run time.
Rebuild it only when updating Acorn/acorn-jsx or changing extraction logic.

    cd lib/react_manifest/vendor/build
    npm ci
    npx esbuild entry.js --bundle --format=iife --minify --outfile=../ast_extractor.js

Verify the rebuilt file with:

    node -e '
      const fs = require("fs");
      eval(fs.readFileSync("../ast_extractor.js", "utf8"));
      console.log(JSON.stringify(__astExtractor.extractUsages("<Foo />")));
    '

Expected output: `{"success":true,"usages":["Foo"]}`
