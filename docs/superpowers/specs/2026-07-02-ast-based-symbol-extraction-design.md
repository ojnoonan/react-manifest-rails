# Optional AST-based symbol extraction via mini_racer

**Date:** 2026-07-02
**Status:** Approved

## Problem

Symbol definition/usage detection (`SymbolExtractor`) is pure regex — no AST parsing, by design, to avoid a hard Node.js dependency. This session surfaced two distinct classes of false positive that are inherent to that approach, not fixable by tightening individual patterns:

1. **Symbol collision** (fixed in v0.2.31, `isolated_app_dirs` added in a later release): two unrelated controller dirs defining the same generic symbol name (e.g. `Show`) cause one to be wrongly treated as depending on the other.
2. **Plain-text false positive** (root cause behind the `isolated_app_dirs` feature): `PASCAL_TOKEN_PATTERN` matches *any* capitalized word anywhere in a file's raw text — including inside JSX text content and string literals. A button labeled `"Show More"` in one controller is textually indistinguishable from a real `<Show />` reference, so it gets treated as a genuine cross-app dependency, pulling a whole unrelated bundle (including anything vendored inside it) into every manifest that happens to contain matching text.

`isolated_app_dirs` is a manual escape hatch for case 2 — it works, but requires the developer to notice the leak and configure it. A real AST can tell "Show" the JSX tag apart from "Show" the button label with certainty, eliminating the false-positive class at the source rather than requiring per-directory opt-out.

The host app for this gem already has `mini_racer`, `terser`, and `libv8-node` (16.19.0.0) installed (for asset minification), meaning an embedded-V8 AST engine costs nothing extra to install for at least this consumer, and follows the same soft-dependency shape the gem already uses for the `listen` gem.

## Goals

- When `mini_racer` is available, use a real JS/JSX AST (Acorn + acorn-jsx) to derive both symbol *definitions* and *usages*, replacing the regex path entirely for that file.
- When `mini_racer` is not available (not installed, fails to load), or a specific file can't be parsed by the AST engine for any reason, fall back to today's regex extraction for that file. Generation must never break because of this feature.
- Zero new hard runtime dependency: `mini_racer` remains something a host app opts into by adding it to their own Gemfile, exactly like `listen` today.
- Every existing call site (`Scanner`, `Generator#build_controller_context`, `component_maps` in `lib/react_manifest.rb`) is unaffected at the call-site level — they keep calling `SymbolExtractor.extract_definitions`/`extract_usages` exactly as today.

## Non-goals

- This does **not** touch TypeScript support beyond what already exists. Acorn does not parse TypeScript syntax; `.ts`/`.tsx` files (when `config.extensions` includes them) always fall back to the regex path under this design. Adding TS support (e.g. via an acorn-typescript plugin) is a future enhancement, not part of this change.
- This does **not** fix or touch the host app's separate `react-rails` JSX-to-JS transform pipeline (its default transformer bridges to Babel 5 via `ruby-babel-transpiler` and cannot parse `??`/`?.`). That is a different gem doing a different job (transforming JSX for the browser to execute) and is tracked as a separate, out-of-scope task (`task_145c3c2e`).
- This does not change generated manifest *content* for any file the AST engine successfully parses in a way that differs from correct behavior — the goal is more accurate detection, not different output shape.

## Design

### Architecture & components

- **`lib/react_manifest/vendor/ast_extractor.js`** — a single, pre-built, committed JS bundle: Acorn + acorn-jsx plus our own extraction logic, wrapped in functions callable from Ruby. Self-contained (no `require`/module resolution), so it loads directly into a `mini_racer::Context`. No network access needed at gem install or run time — committed source, versioned with the gem. Built from the latest stable Acorn + acorn-jsx at implementation time (confirmed ES2020+ support, incl. `??`/`?.`, since Acorn 7.3); no need to pin to an older version for compatibility.
- **`lib/react_manifest/ast_extractor.rb`** — mirrors `SymbolExtractor`'s public interface exactly: `extract_definitions(content)`, `extract_usages(content)`. Lazily creates one `MiniRacer::Context`, memoized at the module level (created once per process, on first use), loads the vendored script into it once, and calls into it per file.
- **`SymbolExtractor` becomes a thin dispatcher.** At load time: `begin; require "mini_racer"; @engine = AstExtractor; rescue LoadError; @engine = <today's regex logic, unchanged>; end`. Decided once per process, mirroring `Watcher.start`'s existing `listen` detection. All existing constants/call sites keep working unchanged.
- **Gemspec**: `mini_racer` added as a **development dependency only** (`spec.add_development_dependency "mini_racer"`), so the gem's own test suite exercises the real AST path in CI. Never a runtime `add_dependency`. README documents it as an opt-in soft dependency, same section as `listen`.

### Data flow & caching

- Per-file extraction is invoked through the exact same entry points as today (`Scanner#extract_definitions_from`, `Generator#extract_defined_symbols`, etc.), which already cache results in `Scanner.file_symbol_cache` keyed by file path and already get invalidated by the file watcher on every add/modify/remove (`Scanner.invalidate(f)`, plus the `component_maps` cache invalidation added earlier this session). No changes to the caching layer — only what computes the cached value changes.
- Call flow: `SymbolExtractor.extract_usages(content)` → dispatches to `AstExtractor.extract_usages(content)` → `context.call("extractUsages", content)` against the persistent V8 context → vendored script parses with Acorn+acorn-jsx, walks its own AST, returns `{usages: [...]}` (or an error object) as JSON → Ruby parses that JSON into a plain array of symbol names, matching `SymbolExtractor`'s existing return shape exactly. Callers never know which engine answered.
- Extraction rules applied JS-side: a *definition* is a top-level `const`/`function`/`class` (or `export` variant) binding a PascalCase or `use`-prefixed identifier — mirrors today's `DEFINITION_PATTERNS` intent but AST-precise. A *usage* is an `Identifier`/`JSXIdentifier` in an actual reference position — JSX element name, call/`new` callee, prop value, array element, object property value — explicitly **excluding** `JSXText` and `StringLiteral` nodes. That exclusion is what fixes the "Show More" class of false positive.

### Error handling

- Every call into the AST engine is wrapped so no failure can break generation. Any failure — JS-side parse error, mini_racer runtime error, or unsupported syntax (`.ts`/`.tsx`) — falls back to today's regex extraction for that one file; generation always completes.
- On any AST failure, a structured warning is always surfaced (not gated behind `config.verbose`) through the existing warnings mechanism (`Scanner#scan`'s `warnings` array — the same channel `react_manifest:analyze` and generation already print through): file path, line, and column when available (real parse errors, since Acorn attaches `loc: {line, column}` to syntax errors), or just a reason when not (e.g. "TypeScript syntax, AST engine skipped"). This is a strict improvement over today's silent regex-only behavior, and over the vague ExecJS-style errors this design was partly motivated by.
- If `mini_racer` itself fails to load, or the vendored script fails to initialize, that's decided **once** at process boot — the dispatcher permanently falls back to the regex engine for the whole process rather than retrying per-file.

## Files changed

| File | Change |
|---|---|
| `lib/react_manifest/vendor/ast_extractor.js` | New. Vendored Acorn + acorn-jsx + extraction logic bundle. |
| `lib/react_manifest/ast_extractor.rb` | New. `MiniRacer`-backed engine implementing `SymbolExtractor`'s interface. |
| `lib/react_manifest/symbol_extractor.rb` | Becomes a dispatcher: detects `mini_racer` once at load, delegates to `AstExtractor` or keeps today's regex logic. |
| `react-manifest-rails.gemspec` | Add `mini_racer` as a development dependency. |
| `README.md` | Document `mini_racer` as an opt-in soft dependency (same section as `listen`), and the per-file fallback/warning behavior. |
| `CHANGELOG.md` | New entry under `[Unreleased]`. |

## Testing

- `mini_racer` is a dev dependency specifically so CI exercises the real AST path, not just the fallback.
- Shared assertions run against both engines directly (`AstExtractor` and today's regex module) to confirm parity on existing happy-path fixtures — definitions, JSX usage, hook calls, etc.
- The false-positive characterization tests already in the suite (symbol collision, "Show" vs. "Show More" plain text) get a companion assertion: still reproduces under the regex-only engine (documents the known limitation), but is fixed under the AST engine.
- New tests for the fallback machinery: a deliberately malformed file triggers per-file fallback plus a line-numbered warning; a `.tsx` fixture (with `extensions` including `tsx`) falls back cleanly with a warning; stubbing `mini_racer`'s `LoadError` confirms the whole process falls back to regex-only with no behavior change from today.
- `SymbolExtractor`'s existing test suite continues to pass unmodified against the dispatcher in both modes, since it asserts on the public interface, not the implementation.
