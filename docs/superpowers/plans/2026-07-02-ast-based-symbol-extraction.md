# Optional AST-based symbol extraction via mini_racer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace regex-based symbol definition/usage detection with a real JS/JSX AST (Acorn + acorn-jsx, run inside an embedded V8 via `mini_racer`) whenever `mini_racer` is available in the host app, falling back to today's regex extraction per-file on any failure — eliminating the plain-text false-positive class of bug (e.g. a `Show` component vs. a "Show More" button label) at the source.

**Architecture:** A vendored, pre-built, self-contained JS bundle (`lib/react_manifest/vendor/ast_extractor.js`) is loaded into a persistent `MiniRacer::Context` by a new `ReactManifest::AstExtractor` module. `ReactManifest::SymbolExtractor` becomes a thin dispatcher: it tries `AstExtractor` first (if `mini_racer` loads), falls back to today's regex logic (renamed, unchanged) per file on any failure, and always surfaces a line-numbered warning via the existing `Logging` module when it does. `mini_racer` is a development-only dependency in the gemspec — host apps opt in themselves, exactly like `listen`.

**Tech Stack:** Ruby, `mini_racer` (embedded V8), Acorn + acorn-jsx (vendored, built via `esbuild`), Minitest.

**Reference spec:** `docs/superpowers/specs/2026-07-02-ast-based-symbol-extraction-design.md`

---

## File Structure

- **Create** `lib/react_manifest/vendor/build/package.json`, `entry.js`, `README.md` — build source for the vendored bundle (not shipped in the gem; only `lib/react_manifest/vendor/ast_extractor.js` is).
- **Create** `lib/react_manifest/vendor/ast_extractor.js` — the committed, pre-built bundle (Acorn + acorn-jsx + extraction logic).
- **Create** `lib/react_manifest/ast_extractor.rb` — `MiniRacer`-backed engine, mirrors `SymbolExtractor`'s interface.
- **Create** `test/react_manifest/ast_extractor_test.rb` — direct tests of the new engine.
- **Modify** `lib/react_manifest/symbol_extractor.rb` — becomes a dispatcher (regex logic renamed and preserved unchanged as the fallback).
- **Modify** `lib/react_manifest/generator.rb` — `extract_defined_symbols` routes through the dispatcher instead of inlining patterns; `extract_used_component_symbols` passes `file_path:`.
- **Modify** `lib/react_manifest/scanner.rb` — `parse_definitions` routes through the dispatcher; `detect_shared_violations`/`detect_external_root_violations` pass `file_path:`. `extract_used_shared_paths` is intentionally left untouched (reporting-only path, bespoke local-symbol logic — see spec's Non-goals).
- **Modify** `lib/react_manifest.rb` — `component_maps`'s `extract_defined_symbols`/`extract_used_component_symbols` pass `file_path:`.
- **Modify** `react-manifest-rails.gemspec` — add `mini_racer` as a development dependency.
- **Modify** `README.md`, `CHANGELOG.md` — document the new soft dependency and behavior.

---

### Task 1: Add mini_racer as a development dependency

**Files:**
- Modify: `react-manifest-rails.gemspec:39-48`

- [ ] **Step 1: Add the dependency**

In `react-manifest-rails.gemspec`, replace:

```ruby
  # listen is a soft runtime dependency (file watching in development).
  # The gem gracefully degrades without it; add to your app's Gemfile:
  #   gem "listen", "~> 3.0", group: :development
  spec.add_development_dependency "listen", "~> 3.0"
end
```

with:

```ruby
  # listen is a soft runtime dependency (file watching in development).
  # The gem gracefully degrades without it; add to your app's Gemfile:
  #   gem "listen", "~> 3.0", group: :development
  spec.add_development_dependency "listen", "~> 3.0"
  # mini_racer is a soft runtime dependency (AST-based symbol extraction).
  # The gem gracefully degrades to regex extraction without it; add to your
  # app's Gemfile to opt in:
  #   gem "mini_racer", group: :development
  spec.add_development_dependency "mini_racer"
end
```

- [ ] **Step 2: Install and verify**

Run: `bundle install`
Expected: Bundler resolves and installs `mini_racer` (and its `libv8-node` dependency) with no errors. This step can take a few minutes on first install (native extension compile).

- [ ] **Step 3: Commit**

```bash
git add react-manifest-rails.gemspec Gemfile.lock
git commit -m "chore: add mini_racer as a development dependency"
```

---

### Task 2: Vendor the Acorn + acorn-jsx extraction bundle

**Files:**
- Create: `lib/react_manifest/vendor/build/package.json`
- Create: `lib/react_manifest/vendor/build/entry.js`
- Create: `lib/react_manifest/vendor/build/README.md`
- Create: `lib/react_manifest/vendor/ast_extractor.js`

- [ ] **Step 1: Create the build directory and package.json**

```bash
mkdir -p lib/react_manifest/vendor/build
```

Create `lib/react_manifest/vendor/build/package.json`:

```json
{
  "name": "react-manifest-rails-ast-extractor-build",
  "private": true,
  "version": "1.0.0",
  "description": "Build source for lib/react_manifest/vendor/ast_extractor.js — not shipped in the gem.",
  "devDependencies": {
    "acorn": "^8.17.0",
    "acorn-jsx": "^5.3.2",
    "esbuild": "^0.28.1"
  }
}
```

- [ ] **Step 2: Write the extraction logic**

Create `lib/react_manifest/vendor/build/entry.js`:

```javascript
// Source for lib/react_manifest/vendor/ast_extractor.js.
// Rebuild with: npm install && npm run build (see README.md in this directory).
import * as acorn from "acorn";
import jsx from "acorn-jsx";

const Parser = acorn.Parser.extend(jsx());

// Mirrors ReactManifest::SymbolExtractor::PASCAL_TOKEN_PATTERN / HOOK_TOKEN_PATTERN.
const PASCAL_OR_HOOK = /^(?:[A-Z][A-Za-z0-9_]*|use[A-Z][A-Za-z0-9_]*)$/;
// Mirrors ReactManifest::SymbolExtractor::LIB_CALL_PATTERN (lowercase function calls).
const LIB_CALL = /^[a-z][A-Za-z0-9_]{2,}$/;

// Mirrors ReactManifest::SymbolExtractor::JS_BUILTINS exactly.
const JS_BUILTINS = new Set([
  "require", "function", "return", "typeof", "instanceof", "delete", "void",
  "console", "document", "window", "location", "history", "navigator",
  "setTimeout", "setInterval", "clearTimeout", "clearInterval",
  "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
  "fetch", "Promise", "Object", "Array", "String", "Number", "Boolean", "Math", "JSON",
  "Symbol", "Map", "Set", "WeakMap",
]);

function parse(content) {
  return Parser.parse(content, {
    ecmaVersion: "latest",
    sourceType: "module",
    locations: true,
  });
}

// Top-level const/let/var/function/class (or export variant) bindings whose
// name is PascalCase or use-prefixed. Mirrors DEFINITION_PATTERNS' intent.
function definitionsFromAst(ast) {
  const defs = [];
  const consider = (id) => {
    if (id && id.type === "Identifier" && PASCAL_OR_HOOK.test(id.name)) defs.push(id.name);
  };
  for (const node of ast.body) {
    let decl = node;
    if (node.type === "ExportNamedDeclaration" || node.type === "ExportDefaultDeclaration") {
      decl = node.declaration;
    }
    if (!decl) continue;
    if (decl.type === "VariableDeclaration") {
      for (const d of decl.declarations) consider(d.id);
    } else if (decl.type === "FunctionDeclaration") {
      consider(decl.id);
    } else if (decl.type === "ClassDeclaration") {
      consider(decl.id);
    }
  }
  return [...new Set(defs)];
}

// Real reference positions only: JSX element names, call/new callees, and
// generic identifier references (prop values, array elements, assignments,
// arguments) — explicitly excluding JSXText and StringLiteral content. This
// is what fixes the "Show" vs. "Show More" plain-text false positive.
function usagesFromAst(ast) {
  const used = new Set();
  const record = (name) => {
    if (JS_BUILTINS.has(name)) return;
    if (PASCAL_OR_HOOK.test(name)) used.add(name);
  };

  function walk(node, parent) {
    if (!node || typeof node.type !== "string") return;

    switch (node.type) {
      case "JSXIdentifier":
        record(node.name);
        break;
      case "CallExpression":
      case "NewExpression":
        if (node.callee && node.callee.type === "Identifier" && LIB_CALL.test(node.callee.name)) {
          if (!JS_BUILTINS.has(node.callee.name)) used.add(node.callee.name);
        }
        break;
      case "Identifier":
        // Skip non-computed member/property-key positions (obj.Foo, {Foo: 1})
        // where the identifier is a property name, not a symbol reference.
        if (parent && parent.type === "MemberExpression" && parent.property === node && !parent.computed) {
          break;
        }
        if (parent && parent.type === "Property" && parent.key === node && !parent.computed) {
          break;
        }
        record(node.name);
        break;
      default:
        break;
    }

    for (const key in node) {
      if (key === "loc" || key === "start" || key === "end" || key === "range") continue;
      const value = node[key];
      if (Array.isArray(value)) {
        for (const child of value) {
          if (child && typeof child.type === "string") walk(child, node);
        }
      } else if (value && typeof value.type === "string") {
        walk(value, node);
      }
    }
  }

  walk(ast, null);
  return [...used];
}

function errorInfo(e) {
  return {
    message: e.message || String(e),
    line: e.loc ? e.loc.line : null,
    column: e.loc ? e.loc.column : null,
  };
}

globalThis.__astExtractor = {
  extractDefinitions(content) {
    try {
      return { success: true, definitions: definitionsFromAst(parse(content)) };
    } catch (e) {
      return { success: false, error: errorInfo(e) };
    }
  },
  extractUsages(content) {
    try {
      const ast = parse(content);
      const defs = new Set(definitionsFromAst(ast));
      const used = usagesFromAst(ast).filter((name) => !defs.has(name));
      return { success: true, usages: used };
    } catch (e) {
      return { success: false, error: errorInfo(e) };
    }
  },
};
```

- [ ] **Step 3: Document the rebuild process**

Create `lib/react_manifest/vendor/build/README.md`:

```markdown
# Build source for ast_extractor.js

`../ast_extractor.js` is a pre-built, committed bundle (Acorn + acorn-jsx +
our own extraction logic) — it is NOT built at gem install or run time.
Rebuild it only when updating Acorn/acorn-jsx or changing extraction logic.

    cd lib/react_manifest/vendor/build
    npm install
    npx esbuild entry.js --bundle --format=iife --minify --outfile=../ast_extractor.js

Verify the rebuilt file with:

    node -e '
      const fs = require("fs");
      eval(fs.readFileSync("../ast_extractor.js", "utf8"));
      console.log(JSON.stringify(__astExtractor.extractUsages("<Foo />")));
    '

Expected output: `{"success":true,"usages":["Foo"]}`
```

- [ ] **Step 4: Build the bundle**

```bash
cd lib/react_manifest/vendor/build
npm install
npx esbuild entry.js --bundle --format=iife --minify --outfile=../ast_extractor.js
cd -
```

Expected: `lib/react_manifest/vendor/ast_extractor.js` is created, roughly 250KB, one line (minified).

- [ ] **Step 5: Verify the bundle works standalone**

```bash
node -e '
  const fs = require("fs");
  eval(fs.readFileSync("lib/react_manifest/vendor/ast_extractor.js", "utf8"));
  const ext = globalThis.__astExtractor;
  console.log(JSON.stringify(ext.extractUsages("const UsersIndex = () => <button>Show More</button>;\n")));
  console.log(JSON.stringify(ext.extractUsages("const UsersDetail = () => <Show />;\n")));
  console.log(JSON.stringify(ext.extractDefinitions("const Show = () => <div />;\n")));
'
```

Expected output (three lines):
```
{"success":true,"usages":[]}
{"success":true,"usages":["Show"]}
{"success":true,"definitions":["Show"]}
```

The first line is the key check: `"Show More"` as plain JSX text produces zero usages.

- [ ] **Step 6: Ensure the build directory's node_modules is ignored**

Check `.gitignore` for a `node_modules` entry; if absent, add one scoped to the build dir:

```bash
grep -q "^node_modules" .gitignore 2>/dev/null || echo "lib/react_manifest/vendor/build/node_modules" >> .gitignore
```

- [ ] **Step 7: Commit**

```bash
git add lib/react_manifest/vendor/ lib/react_manifest/vendor/build/package.json .gitignore
git add -f lib/react_manifest/vendor/ast_extractor.js lib/react_manifest/vendor/build/entry.js lib/react_manifest/vendor/build/README.md lib/react_manifest/vendor/build/package-lock.json
git commit -m "feat: vendor Acorn+acorn-jsx AST extraction bundle"
```

---

### Task 3: Build the AstExtractor Ruby module (TDD)

**Files:**
- Create: `lib/react_manifest/ast_extractor.rb`
- Test: `test/react_manifest/ast_extractor_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/react_manifest/ast_extractor_test.rb`:

```ruby
require "test_helper"
require "react_manifest/ast_extractor"

class AstExtractorTest < ReactManifestTest
  def test_extract_definitions_finds_pascal_case_const
    assert_equal ["Show"], ReactManifest::AstExtractor.extract_definitions("const Show = () => <div />;\n")
  end

  def test_extract_usages_ignores_plain_jsx_text
    content = "const UsersIndex = () => <button>Show More</button>;\n"
    assert_equal [], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_usages_detects_real_jsx_reference
    content = "const UsersDetail = () => <Show />;\n"
    assert_equal ["Show"], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_usages_detects_lowercase_lib_call
    content = "const result = formatDate(value);\n"
    assert_includes ReactManifest::AstExtractor.extract_usages(content), "formatDate"
  end

  def test_extract_usages_excludes_js_builtins
    content = "fetch('/api').then(r => r.json());\n"
    refute_includes ReactManifest::AstExtractor.extract_usages(content), "fetch"
  end

  def test_extract_usages_excludes_self_reference
    content = "const MyWidget = () => <MyWidget />;\n"
    assert_equal [], ReactManifest::AstExtractor.extract_usages(content)
  end

  def test_extract_definitions_returns_nil_and_warns_on_syntax_error
    Rails.logger.expects(:warn).with { |msg| msg.include?("broken.jsx") && msg.include?("line 3") }
    result = ReactManifest::AstExtractor.extract_definitions("const Broken = () => {\n  return <div>\n};\n",
                                                              file_path: "broken.jsx")
    assert_nil result
  end

  def test_extract_usages_returns_nil_and_warns_on_syntax_error
    Rails.logger.expects(:warn).with { |msg| msg.include?("broken.jsx") }
    result = ReactManifest::AstExtractor.extract_usages("const Broken = () => {\n  return <div>\n};\n",
                                                          file_path: "broken.jsx")
    assert_nil result
  end

  def test_warning_omits_filename_when_not_provided
    Rails.logger.expects(:warn).with { |msg| msg.include?("unknown file") }
    ReactManifest::AstExtractor.extract_usages("const Broken = () => {\n  return <div>\n};\n")
  end
end
```

Note the explicit `require "react_manifest/ast_extractor"` — this task tests `AstExtractor` in isolation, before Task 4 wires it into the dispatcher (which is what makes it load automatically for the rest of the codebase). Without this line, every test in this file fails with `NameError: uninitialized constant ReactManifest::AstExtractor` regardless of whether the module has been implemented.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rake test TEST=test/react_manifest/ast_extractor_test.rb`
Expected: FAIL — `NameError: uninitialized constant ReactManifest::AstExtractor` (the module doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `lib/react_manifest/ast_extractor.rb`:

```ruby
require "mini_racer"
require "json"
require_relative "logging"

module ReactManifest
  # AST-based symbol extraction backed by an embedded V8 (mini_racer).
  # Mirrors SymbolExtractor's public interface exactly. Never raises — any
  # parse or runtime failure returns nil (after logging a warning) so the
  # caller (SymbolExtractor's dispatcher) can fall back to regex extraction
  # for that one file.
  module AstExtractor
    VENDOR_SCRIPT = File.expand_path("vendor/ast_extractor.js", __dir__)

    GLUE = <<~JS.freeze
      function __reactManifestExtractDefinitions(content) {
        return JSON.stringify(__astExtractor.extractDefinitions(content));
      }
      function __reactManifestExtractUsages(content) {
        return JSON.stringify(__astExtractor.extractUsages(content));
      }
    JS

    class << self
      include ReactManifest::Logging

      def extract_definitions(content, file_path: nil)
        result = call_js("__reactManifestExtractDefinitions", content)
        return result["definitions"] if result["success"]

        report_error(file_path, result["error"])
        nil
      end

      def extract_usages(content, file_path: nil)
        result = call_js("__reactManifestExtractUsages", content)
        return result["usages"] if result["success"]

        report_error(file_path, result["error"])
        nil
      end

      private

      def context
        @context ||= begin
          ctx = MiniRacer::Context.new
          ctx.eval(File.read(VENDOR_SCRIPT))
          ctx.eval(GLUE)
          ctx
        end
      end

      def call_js(function_name, content)
        JSON.parse(context.call(function_name, content))
      rescue StandardError => e
        { "success" => false, "error" => { "message" => e.message, "line" => nil, "column" => nil } }
      end

      def report_error(file_path, error)
        location = file_path || "unknown file"
        location = "#{location} at line #{error['line']}, column #{error['column']}" if error && error["line"]
        message = error ? error["message"] : "unknown error"
        log_warn "AST parse failed for #{location}: #{message} — falling back to regex extraction for this file."
      end
    end
  end
end
```

Note: `.freeze` on `GLUE` and the `call_js`/`function_name` naming (not `call`/`fn`) are required to satisfy this project's RuboCop config (`Style/MutableConstant`, `Naming/MethodParameterName` — verified empirically before writing this plan; the shorter, more obvious names fail `bundle exec rubocop --parallel`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rake test TEST=test/react_manifest/ast_extractor_test.rb`
Expected: PASS (9 runs, 0 failures)

- [ ] **Step 5: Run rubocop and autocorrect**

Run: `bundle exec rubocop -a lib/react_manifest/ast_extractor.rb test/react_manifest/ast_extractor_test.rb`

Expected (verified empirically before writing this plan): 2 `Layout/ArgumentAlignment` offenses in `test_extract_definitions_returns_nil_and_warns_on_syntax_error` and `test_extract_usages_returns_nil_and_warns_on_syntax_error` (the multi-line `extract_definitions`/`extract_usages` calls from Step 1) — both auto-corrected. `lib/react_manifest/ast_extractor.rb` itself should already be clean if written exactly as shown in Step 3 (`.freeze` on `GLUE`, `call_js`/`function_name` naming — a bare `call`/`fn` fails `Naming/MethodParameterName` and an unfrozen `GLUE` fails `Style/MutableConstant`).

Run: `bundle exec rubocop --parallel`
Expected: `no offenses detected`

- [ ] **Step 6: Commit**

```bash
git add lib/react_manifest/ast_extractor.rb test/react_manifest/ast_extractor_test.rb
git commit -m "feat: add AstExtractor module backed by mini_racer"
```

---

### Task 4: Make SymbolExtractor a dispatcher with per-file fallback

**Files:**
- Modify: `lib/react_manifest/symbol_extractor.rb`
- Test: `test/react_manifest/symbol_extractor_test.rb`
- Test: `test/react_manifest/generator_test.rb` (updating a now-outdated characterization test — see Step 6)

- [ ] **Step 1: Write the failing tests**

Add to `test/react_manifest/symbol_extractor_test.rb`, just before the final `end`:

```ruby
  # --- dispatcher: AST engine used when available ---

  def test_extract_usages_uses_ast_engine_when_available
    content = "const UsersIndex = () => <button>Show More</button>;\n"
    assert_equal [], ReactManifest::SymbolExtractor.extract_usages(content)
  end

  def test_extract_usages_falls_back_to_regex_for_a_file_the_ast_engine_cannot_parse
    # Adjacent bare JSX elements are invalid JSX (Acorn/Babel both reject this),
    # but the regex fallback doesn't care and matches "Foo" via plain text scan.
    content = "<Foo /><Foo /><Foo />"
    result = ReactManifest::SymbolExtractor.extract_usages(content)
    assert_equal ["Foo"], result
  end

  def test_extract_definitions_falls_back_to_regex_when_ast_engine_unavailable
    ReactManifest::SymbolExtractor.stubs(:ast_engine_available?).returns(false)
    assert_includes ReactManifest::SymbolExtractor.extract_definitions("const FooBar = () => {};"), "FooBar"
  end

  def test_extract_usages_falls_back_to_regex_when_ast_engine_unavailable
    ReactManifest::SymbolExtractor.stubs(:ast_engine_available?).returns(false)
    content = "const UsersIndex = () => <button>Show More</button>;\n"
    # The regex engine cannot tell JSX text apart from a real reference —
    # this documents the known limitation being fixed by the AST engine.
    assert_includes ReactManifest::SymbolExtractor.extract_usages(content), "Show"
  end

  def test_extract_usages_passes_file_path_through_to_ast_engine_for_warnings
    Rails.logger.expects(:warn).with { |msg| msg.include?("my/file.jsx") }
    ReactManifest::SymbolExtractor.extract_usages("const Broken = () => {\n  return <div>\n};\n",
                                                    file_path: "my/file.jsx")
  end
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bundle exec rake test TEST=test/react_manifest/symbol_extractor_test.rb`

Expected: 2 of the 5 new tests fail against today's code (verified empirically before writing this plan):
- `test_extract_usages_uses_ast_engine_when_available` — FAILS: `Expected: [] / Actual: ["Show", "More"]` (today's regex engine can't tell JSX text from a real reference, and both capitalized words in "Show More" match `PASCAL_TOKEN_PATTERN`).
- `test_extract_usages_passes_file_path_through_to_ast_engine_for_warnings` — ERRORS: `ArgumentError: wrong number of arguments (given 2, expected 1)` (today's `extract_usages(content)` takes no keyword arguments).

The other 3 new tests (`test_extract_usages_falls_back_to_regex_for_a_file_the_ast_engine_cannot_parse`, `test_extract_definitions_falls_back_to_regex_when_ast_engine_unavailable`, `test_extract_usages_falls_back_to_regex_when_ast_engine_unavailable`) already PASS against today's code — they assert regex-fallback behavior that today's pure-regex implementation already exhibits by definition, and `.stubs(:ast_engine_available?)` on a not-yet-existing method doesn't raise (Mocha allows stubbing methods that don't exist yet). They're included as forward-looking regression/characterization tests, not red/green TDD signals — they must keep passing after Step 3, not just start passing.

- [ ] **Step 3: Rewrite SymbolExtractor as a dispatcher**

Replace the full contents of `lib/react_manifest/symbol_extractor.rb`:

```ruby
module ReactManifest
  module SymbolExtractor
    DEFINITION_PATTERNS = [
      /(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,
      /function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,
      /class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/,
      /(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,
      /function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+default\s+(?:function|class)\s+([A-Z][A-Za-z0-9_]*)/,
      /^export\s+default\s+(?:function|class)\s+(use[A-Z][A-Za-z0-9_]*)/,
      /^export\s+(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/
    ].freeze

    PASCAL_TOKEN_PATTERN = /\b([A-Z][A-Za-z0-9_]*)\b/
    HOOK_TOKEN_PATTERN   = /\b(use[A-Z][A-Za-z0-9_]*)\b/
    LIB_CALL_PATTERN     = /\b([a-z][A-Za-z0-9_]{2,})\s*\(/

    JS_BUILTINS = %w[
      require function return typeof instanceof delete void
      console document window location history navigator
      setTimeout setInterval clearTimeout clearInterval
      parseInt parseFloat isNaN isFinite encodeURI decodeURI
      fetch Promise Object Array String Number Boolean Math JSON
      Object Array String Number Boolean Symbol Map Set WeakMap
    ].freeze

    module_function

    # Uses the AST engine (mini_racer) when available; falls back to regex
    # extraction for this content on any AST failure (unavailable engine,
    # parse error, unsupported syntax such as TypeScript).
    def extract_definitions(content, file_path: nil)
      return [] unless content

      if ast_engine_available?
        result = AstExtractor.extract_definitions(content, file_path: file_path)
        return result if result
      end

      regex_extract_definitions(content)
    end

    def extract_usages(content, file_path: nil)
      return [] unless content

      if ast_engine_available?
        result = AstExtractor.extract_usages(content, file_path: file_path)
        return result if result
      end

      regex_extract_usages(content)
    end

    # Decided once per process: does `require "mini_racer"` succeed?
    def ast_engine_available?
      return @ast_engine_available if defined?(@ast_engine_available)

      @ast_engine_available = begin
        require_relative "ast_extractor"
        true
      rescue LoadError
        false
      end
    end

    def regex_extract_definitions(content)
      symbols = []
      DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    end

    def regex_extract_usages(content)
      local_syms = Set.new
      DEFINITION_PATTERNS.each { |p| content.scan(p) { |m| local_syms << m[0] } }

      used = []

      content.scan(PASCAL_TOKEN_PATTERN) do |match|
        sym = match[0]
        used << sym unless local_syms.include?(sym)
      end

      content.scan(HOOK_TOKEN_PATTERN) do |match|
        sym = match[0]
        used << sym unless local_syms.include?(sym)
      end

      content.scan(LIB_CALL_PATTERN) do |match|
        sym = match[0]
        used << sym unless JS_BUILTINS.include?(sym) || local_syms.include?(sym)
      end

      used.uniq
    end
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rake test TEST=test/react_manifest/symbol_extractor_test.rb`
Expected: PASS — all tests in the file (existing 43 + 5 new = 48 runs, 0 failures)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `bundle exec rake test`

Expected: exactly ONE failure (verified empirically before writing this plan) —

```
GeneratorRunTest#test_plain_jsx_text_matching_a_component_name_falsely_pulls_in_unrelated_bundle
expected today's known false-positive leak to reproduce.
Expected "...//= require ux/app/users/users_index\n" to include "ux/app/rvb/".
```

This is the **correct, expected outcome, not a regression.** `test/react_manifest/generator_test.rb` has an existing characterization test (added earlier this session, before this feature existed) that deliberately asserts the plain-text false positive still reproduces — its own explicit assertion message says `"expected today's known false-positive leak to reproduce"`. `Generator#extract_used_component_symbols` already called `SymbolExtractor.extract_usages` before this plan touched anything, so as soon as the dispatcher routes to the AST engine (this step), that exact false positive — the one that originally motivated this whole design — is fixed. The test needs to be updated to assert the new, correct behavior, not left failing.

- [ ] **Step 6: Update the now-outdated characterization test**

In `test/react_manifest/generator_test.rb`, replace:

```ruby
  def test_plain_jsx_text_matching_a_component_name_falsely_pulls_in_unrelated_bundle
    # No AST parsing means "Show" as a JSX tag and "Show" as plain button text
    # are textually indistinguishable to the regex scanner.
    rvb_dir = Rails.root.join("app/assets/javascripts/ux/app/rvb")
    users_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(rvb_dir)
    FileUtils.mkdir_p(users_dir)

    File.write(rvb_dir.join("rvb_show.js.jsx"), "const Show = () => <div>Builder preview</div>;\n")
    File.write(rvb_dir.join("babel.min.js"), "var A=1,B=2,C=3;\n")
    File.write(users_dir.join("users_index.js.jsx"), "const UsersIndex = () => <button>Show More</button>;\n")

    @generator.run!
    content = read_manifest("ux_users.js")

    assert_includes content, "ux/app/rvb/", "expected today's known false-positive leak to reproduce"
  end
```

with:

```ruby
  def test_plain_jsx_text_matching_a_component_name_does_not_pull_in_unrelated_bundle
    # Regex-only scanning can't tell "Show" the JSX tag apart from "Show" as
    # plain button text (a known limitation — see isolated_app_dirs). With
    # the AST engine available (mini_racer is a dev dependency, so it always
    # is in this test suite), a real AST correctly distinguishes the two.
    rvb_dir = Rails.root.join("app/assets/javascripts/ux/app/rvb")
    users_dir = Rails.root.join("app/assets/javascripts/ux/app/users")
    FileUtils.mkdir_p(rvb_dir)
    FileUtils.mkdir_p(users_dir)

    File.write(rvb_dir.join("rvb_show.js.jsx"), "const Show = () => <div>Builder preview</div>;\n")
    File.write(rvb_dir.join("babel.min.js"), "var A=1,B=2,C=3;\n")
    File.write(users_dir.join("users_index.js.jsx"), "const UsersIndex = () => <button>Show More</button>;\n")

    @generator.run!
    content = read_manifest("ux_users.js")

    refute_includes content, "ux/app/rvb/"
  end
```

- [ ] **Step 7: Run the full test suite again**

Run: `bundle exec rake test`
Expected: PASS — 325 runs, 0 failures, 0 errors.

- [ ] **Step 8: Run rubocop and autocorrect layout offenses**

Run: `bundle exec rubocop -a test/react_manifest/symbol_extractor_test.rb`
Expected: one `Layout/ArgumentAlignment` offense in `test_extract_usages_passes_file_path_through_to_ast_engine_for_warnings` (the multi-line `extract_usages(...)` call from Step 1), auto-corrected.

Run: `bundle exec rubocop --parallel`
Expected: `no offenses detected`

- [ ] **Step 9: Commit**

```bash
git add lib/react_manifest/symbol_extractor.rb test/react_manifest/symbol_extractor_test.rb test/react_manifest/generator_test.rb
git commit -m "feat: make SymbolExtractor dispatch to AstExtractor with per-file regex fallback"
```

---

### Task 5: Thread file_path through remaining call sites

**Files:**
- Modify: `lib/react_manifest/generator.rb:396-412`
- Modify: `lib/react_manifest/scanner.rb:157-239`
- Modify: `lib/react_manifest.rb:215-227`
- Test: `test/react_manifest/generator_test.rb`
- Test: `test/react_manifest/scanner_test.rb` (fixing a pre-existing test's now-stale method stub — see Step 7)

- [ ] **Step 1: Write the failing test**

`generator_test.rb` has two test classes (`GeneratorRunTest`, then `GeneratorCleanTest`). This test uses `@generator`/`output_dir`, which only `GeneratorRunTest` sets up — add it as the last method **inside `GeneratorRunTest`**, immediately before that class's closing `end` (the one right before `class GeneratorCleanTest < ReactManifestTest` — NOT the file's last `end`, which closes the wrong class):

```ruby
  def test_definition_parse_failure_falls_back_and_warns_with_file_path
    ctrl_dir = Rails.root.join("app/assets/javascripts/ux/app/broken")
    FileUtils.mkdir_p(ctrl_dir)
    File.write(ctrl_dir.join("broken.js.jsx"), "const Broken = () => {\n  return <div>\n};\n")

    warn_calls = []
    $stdout.stubs(:puts)
    Rails.logger.stubs(:warn).with do |msg|
      warn_calls << msg
      true
    end

    @generator.run!

    assert(warn_calls.any? { |m| m.include?("broken.js.jsx") && m.include?("line") },
           "expected a line-numbered warning naming the broken file, got: #{warn_calls.inspect}")
    assert File.exist?(File.join(output_dir, "ux_broken.js")), "generation should still complete for other files"
  end
```

- [ ] **Step 2: Run the test to verify it fails**

This project's `rake test` `TEST=` filter does not support Minitest's `-n` flag directly (verified — it errors with "File does not exist"); run the whole file and check this test's result:

Run: `bundle exec rake test TEST=test/react_manifest/generator_test.rb`
Expected: FAIL — `GeneratorRunTest#test_definition_parse_failure_falls_back_and_warns_with_file_path`:
```
expected a line-numbered warning naming the broken file, got: ["[ReactManifest] AST parse failed for unknown file at line 3, column 0: Unexpected token `}`. ... — falling back to regex extraction for this file."]
```
(the warning says `"unknown file"` because `file_path:` isn't threaded through yet — every other test in the file still passes)

- [ ] **Step 3: Update Generator**

In `lib/react_manifest/generator.rb`, replace:

```ruby
    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      symbols = []
      ReactManifest::Scanner::DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end
```

with:

```ruby
    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_definitions(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end
```

- [ ] **Step 4: Update Scanner**

In `lib/react_manifest/scanner.rb`, replace:

```ruby
    def extract_definitions(file_path)
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = scan_file_definitions(file_path)
    end

    # Like extract_definitions but uses pre-read content, populating the cache as a side-effect.
    def extract_definitions_from(file_path, content)
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = parse_definitions(content)
    end

    def scan_file_definitions(file_path)
      begin
        content = File.read(file_path, encoding: "utf-8")
      rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
        return []
      end
      parse_definitions(content)
    end

    def parse_definitions(content)
      return [] unless content

      symbols = []
      DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    end
```

with:

```ruby
    def extract_definitions(file_path)
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = scan_file_definitions(file_path)
    end

    # Like extract_definitions but uses pre-read content, populating the cache as a side-effect.
    def extract_definitions_from(file_path, content)
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = parse_definitions(content, file_path: file_path)
    end

    def scan_file_definitions(file_path)
      begin
        content = File.read(file_path, encoding: "utf-8")
      rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
        return []
      end
      parse_definitions(content, file_path: file_path)
    end

    def parse_definitions(content, file_path: nil)
      return [] unless content

      SymbolExtractor.extract_definitions(content, file_path: file_path)
    end
```

Then, in the same file, replace:

```ruby
    def detect_shared_violations(shared_file_paths, shared_file_content, controller_symbol_index, warnings)
      violations = []
      shared_file_paths.each do |file_path, relative|
        content = shared_file_content[file_path]
        next unless content

        SymbolExtractor.extract_usages(content).each do |sym|
```

with:

```ruby
    def detect_shared_violations(shared_file_paths, shared_file_content, controller_symbol_index, warnings)
      violations = []
      shared_file_paths.each do |file_path, relative|
        content = shared_file_content[file_path]
        next unless content

        SymbolExtractor.extract_usages(content, file_path: file_path).each do |sym|
```

And replace:

```ruby
    def detect_external_root_violations(external_file_paths, controller_symbol_index, warnings)
      violations = []
      external_file_paths.each do |file_path, relative|
        content = begin
          File.read(file_path, encoding: "utf-8")
        rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
          next
        end

        SymbolExtractor.extract_usages(content).each do |sym|
```

with:

```ruby
    def detect_external_root_violations(external_file_paths, controller_symbol_index, warnings)
      violations = []
      external_file_paths.each do |file_path, relative|
        content = begin
          File.read(file_path, encoding: "utf-8")
        rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
          next
        end

        SymbolExtractor.extract_usages(content, file_path: file_path).each do |sym|
```

- [ ] **Step 5: Update lib/react_manifest.rb**

In `lib/react_manifest.rb`, replace:

```ruby
    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_definitions(content)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end
```

with:

```ruby
    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_definitions(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bundle exec rake test TEST=test/react_manifest/generator_test.rb`
Expected: PASS — `GeneratorRunTest#test_definition_parse_failure_falls_back_and_warns_with_file_path` and every other test in the file pass.

- [ ] **Step 7: Fix a pre-existing test that stubs the old parse_definitions signature**

Run: `bundle exec rake test TEST=test/react_manifest/scanner_test.rb`

Expected (verified empirically before writing this plan): 1 error —

```
ScannerTest#test_rescans_only_invalidated_file_leaving_others_cached:
ArgumentError: wrong number of arguments (given 2, expected 1)
    test/react_manifest/scanner_test.rb:469:in 'block in test_rescans_only_invalidated_file_leaving_others_cached'
```

This test overrides `parse_definitions` with a singleton method to spy on calls, using the OLD single-positional-argument signature. Since Step 4 changed the real signature to `parse_definitions(content, file_path: nil)`, the spy's signature no longer matches what `Scanner#extract_definitions_from` actually calls it with.

In `test/react_manifest/scanner_test.rb`, replace:

```ruby
    rescanned = []
    original_parse = @scanner.method(:parse_definitions)
    @scanner.define_singleton_method(:parse_definitions) do |content|
      rescanned << content
      original_parse.call(content)
    end
```

with:

```ruby
    rescanned = []
    original_parse = @scanner.method(:parse_definitions)
    @scanner.define_singleton_method(:parse_definitions) do |content, file_path: nil|
      rescanned << content
      original_parse.call(content, file_path: file_path)
    end
```

Run: `bundle exec rake test TEST=test/react_manifest/scanner_test.rb`
Expected: PASS — all tests in the file pass.

- [ ] **Step 8: Run the full test suite**

Run: `bundle exec rake test`
Expected: PASS — 326 runs, 0 failures, 0 errors.

- [ ] **Step 9: Run rubocop**

Run: `bundle exec rubocop --parallel`
Expected: `no offenses detected`

- [ ] **Step 10: Commit**

```bash
git add lib/react_manifest/generator.rb lib/react_manifest/scanner.rb lib/react_manifest.rb test/react_manifest/generator_test.rb test/react_manifest/scanner_test.rb
git commit -m "feat: thread file_path through to SymbolExtractor for precise AST warnings"
```

---

### Task 6: Documentation and stress test

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Document the soft dependency in README**

In `README.md`, find the `### Key option notes` section (search for `**\`stdout_logging\`**`) and add a new bullet immediately after it:

```markdown
- **AST-based symbol extraction**: add `gem "mini_racer"` to your Gemfile to opt in. When present, definitions and usages are derived from a real JS/JSX AST (Acorn) instead of regex, which fixes false positives like a `Show` component colliding with unrelated text such as a "Show More" button label. Falls back to regex extraction per-file on any parse failure (always logged via `Rails.logger.warn` with file/line/column when available) — generation never breaks because of this. Without `mini_racer`, behavior is unchanged from today.
```

- [ ] **Step 2: Update CHANGELOG**

In `CHANGELOG.md`, replace:

```markdown
## [Unreleased]
```

with:

```markdown
## [Unreleased]

### Added
- Optional AST-based symbol extraction: add `gem "mini_racer"` to opt in. Definitions and usages are derived from a real JS/JSX AST (Acorn + acorn-jsx) instead of regex when available, fixing false positives where an unrelated word (e.g. plain JSX text like "Show More") is indistinguishable from a real component reference to a regex scanner. Falls back to regex extraction per-file on any parse failure, always with a line-numbered warning. No behavior change for apps that don't add `mini_racer`.
```

- [ ] **Step 3: Run the full suite and stress tests one final time**

Run: `bundle exec rake test && bundle exec rake test:stress && bundle exec rubocop --parallel`
Expected: all pass, 0 failures, 0 offenses.

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document optional AST-based symbol extraction"
```

---

## Self-Review Notes

- **Spec coverage:** Goals (AST when available, per-file regex fallback, zero new hard dependency, call sites unaffected at signature-compatible level) — Tasks 1-5. Non-goals (no TypeScript AST support, react-rails transform untouched) — no task implements TS support, confirmed by design (Acorn has no TS plugin vendored); nothing in this plan touches react-rails. Error handling (always-on line-numbered warnings, per-file fallback, process-wide fallback if mini_racer unavailable) — Task 3 (`AstExtractor`) and Task 4 (`SymbolExtractor` dispatcher). Testing strategy (parity tests, false-positive-fixed test, fallback machinery tests) — Tasks 3-5.
- **Scope clarification vs. spec:** the spec assumed every call site already routed through `SymbolExtractor`'s public interface; verified during planning that two did not (`Generator#extract_defined_symbols`, `Scanner#parse_definitions` both inlined regex patterns directly). Confirmed with the user to refactor both — done in Task 5. `Scanner#extract_used_shared_paths` is intentionally left on its own inline regex logic (reporting-only `react_manifest:analyze` path, bespoke local-symbol-exclusion logic not a clean match for the extract_usages interface) — explicitly noted, not a silent gap.
- **Type consistency:** `extract_definitions(content, file_path: nil)` / `extract_usages(content, file_path: nil)` signature is identical across `SymbolExtractor` and `AstExtractor`. `AstExtractor` returns `nil` on failure (never raises); `SymbolExtractor`'s dispatcher checks for that specific `nil` to trigger fallback — consistent in both Task 3 and Task 4's code.
- All vendoring commands and extraction logic in Task 2 were validated end-to-end (parsed against all 43 existing `SymbolExtractorTest` cases plus the target false-positive case, and re-verified running inside an actual `MiniRacer::Context`, not just plain Node) before being written into this plan.
- **Full dry run:** every task in this plan (1 through 5) was actually applied to this working tree, every specified command run, and every "Expected" output checked against real output — then fully reverted (`git checkout` + `rm`) before this document was finalized, so nothing here is a guess. This caught and fixed 7 real inaccuracies that would otherwise have derailed execution: an incorrect existing-test count (43, not 25), a missing `require` needed for Task 3's tests to resolve `AstExtractor` at all (nothing loads that file until Task 4 wires the dispatcher), a wrong line number in a syntax-error assertion, a wrong insertion point that would have added a test to the wrong class (`GeneratorCleanTest` instead of `GeneratorRunTest`), a `-n` test-filter flag that doesn't work with this project's `rake test` (must run the whole file), two RuboCop violations in the planned Ruby code (`Style/MutableConstant`, `Naming/MethodParameterName`) plus alignment offenses in the new test files, and a pre-existing test (`scanner_test.rb`) that stubs `parse_definitions` with a now-stale single-argument signature. Task 4 Step 5's "expected failure" is itself a real, load-bearing verification: the one pre-existing test that fails after the dispatcher lands is the exact false-positive bug this whole plan exists to fix — a green run there would have meant the feature wasn't actually wired in.
