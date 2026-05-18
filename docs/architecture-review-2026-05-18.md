# Architecture Review — 2026-05-18

Context: pre-production deploy review. Candidates ranked by production risk, not aesthetic cleanliness.

---

## Candidate 1 — Triplicated symbol-extraction logic *(highest production risk)*

**Status: DONE** — commit `46bf129` (issues #30, #31, #29)

**Files:**
- `lib/react_manifest.rb:187–218` (`extract_defined_symbols`, `extract_used_component_symbols`)
- `lib/react_manifest/scanner.rb:194–354` (`extract_definitions`, `extract_used_shared_paths`)
- `lib/react_manifest/generator.rb:378–409`

**Problem:**
Three separate regex implementations of the same behaviour: extracting defined symbols and used references from JS/JSX files. They have already diverged — `react_manifest.rb` skips the `JS_BUILTINS` filter that `scanner.rb` applies; `generator.rb` skips it too. A bug fix in one will not propagate to the others.

In production this means `resolve_bundles` (called by the view helper at render time) can make different decisions than the Scanner made at generation time — so the right bundle gets generated but the wrong one gets served, or vice versa. **This is a silent correctness bug, not just a code smell.** The deletion test is clear: deleting any one copy leaves the other two still working, which proves they are diverging parallel implementations rather than genuine collaborators.

**Solution:**
Consolidated into `SymbolExtractor` (`lib/react_manifest/symbol_extractor.rb`) with two `module_function` methods: `extract_definitions(content)` and `extract_usages(content)`. All five call sites in `scanner.rb`, `generator.rb`, and `react_manifest.rb` now delegate here. Single copy of `DEFINITION_PATTERNS`, `JS_BUILTINS`, and the three usage-scan patterns.

**Benefits:**
- *Locality:* a regex change or builtin addition is made once and takes effect everywhere.
- *Leverage:* callers get correct, consistent symbol sets without knowing anything about regex or builtins.
- *Tests:* the extractor can be unit-tested in isolation with fixture JS strings; the integration tests shrink to verifying wiring rather than correctness.

---

## Candidate 2 — `exclude_paths` has three independent implementations *(medium production risk)*

**Status: DONE** — commit `0ddd9dd` (issues #33, #34)

**Files:**
- `lib/react_manifest/scanner.rb:189–191`
- `lib/react_manifest/generator.rb:366–368`
- `lib/react_manifest/tree_classifier.rb` (implicit via `shared_dirs` logic)

**Problem:**
Each module re-implements its own version of "is this path excluded?" with no shared predicate. If a user adds an `exclude_paths` entry and it works in the generator but not the scanner, excluded files get scanned and their symbols appear in manifests. No test cross-validates the three against the same input. The seam exists in configuration but the adapters are all hand-rolled independently.

**Solution:**
Extracted `Configuration#excluded_path?(abs_path)` — splits the path on `File::SEPARATOR` and checks whether any segment appears in `exclude_paths`. Scanner and Generator now call `config.excluded_path?` at their respective filter points; the implicit tree-classifier logic was already correct via `shared_dirs` and did not need changing.

**Benefits:**
- *Locality:* exclusion logic lives in one module. Changing glob semantics or adding a new exclusion type is a one-line edit.
- *Leverage:* callers pass a path and get a boolean; they don't know anything about pattern matching.
- *Tests:* a single parameterised test suite covers all exclusion cases once; the three callers only need to verify they call the predicate.

---

## Candidate 3 — Component-map cache invalidates on object identity, not values *(medium production risk)*

**Status: DONE** — commit `3bfbc76` (issues #35, #36, #37)

**Files:**
- `lib/react_manifest.rb:139–177` (`@component_maps_cache`, `reset!`)

**Problem:**
`@component_maps_cache` is keyed by the configuration object. Mutating config after the first call (e.g. `ReactManifest.configure` called a second time in a Rails initializer, which is a supported pattern) does not bust the cache unless `reset!` is called explicitly. Tests never mutate config mid-session. In production this means a re-configure in a multi-step initializer silently serves stale component maps — the wrong bundles, or missing `always_include` entries.

**Solution:**
Added `Configuration#cache_key` — a Ruby `Array#hash` over the six fields that affect component maps (`ux_root`, `app_dir`, `extensions`, `always_include`, `exclude_paths`, `external_providers`). `@component_maps_cache` is now a two-element array `[cache_key, maps]`; any value change produces a different key and the maps are recomputed on the next call without requiring `reset!`.

**Benefits:**
- *Locality:* cache correctness is enforced at the seam, not scattered across every caller that might mutate config.
- *Leverage:* callers get fresh maps after a configure call with zero additional protocol.
- *Tests:* a single test mutates config and asserts the next call returns updated maps, without needing to call `reset!`.

---

## Candidate 4 — ViewHelpers shares deduplication state via `request.env` with a nil fallback *(low-medium production risk)*

**Status: SKIPPED** — app does not render views outside a request context; nil-request path is dead code. Deferred post-deploy.

**Files:**
- `lib/react_manifest/view_helpers.rb:72–92`

**Problem:**
`react_bundle_tag` and `react_component` write to `request.env` to track which bundles have been emitted this request, preventing duplicate `<script>` tags. If `request` is nil (mailers, console sessions, background jobs that render partials), the code falls back to an instance variable. The test suite never exercises that fallback path. In production this risks double-emitting `<script>` tags or emitting none at all in non-request rendering contexts — both silent failures.

**Solution (deferred):**
Extract a `BundleEmissionTracker` that owns the emitted-set and knows how to find its storage location (request env if available, otherwise a thread-local or instance store). ViewHelpers delegates entirely; it does not inspect `request` directly. The tracker's interface is simple (`emitted?`, `mark_emitted`); the fallback logic lives behind the seam.

**Benefits:**
- *Locality:* the nil-request fallback, the env key, and the deduplication logic are in one place.
- *Leverage:* ViewHelpers methods become one-liners; the tracker can be tested independently with and without a request object.
- *Tests:* the nil-request path gets its own unit tests rather than relying on production incidents to discover it.

---

## Candidate 5 — `Generator#build_controller_context` is a 75-line opaque hash builder *(testability risk — not an immediate production fire)*

**Files:**
- `lib/react_manifest/generator.rb:133–207`

**Problem:**
A single 75-line method initialises 9 intermediate hashes, re-runs symbol extraction despite having scan results already passed in, and returns an untyped 5-key hash. No test inspects the output of this method directly; only end-to-end manifest diffs reveal if the dependency mapping is wrong. Feedback loop on bugs is slow.

**Solution:**
Split into named steps that each return a typed value: scan result → dependency set → manifest lines. Each step is testable in isolation. The method becomes an orchestrator of named operations rather than an accumulator of local variables.

**Benefits:**
- *Locality:* if dependency mapping is wrong, a unit test on the mapping step catches it before manifest generation.
- *Leverage:* callers (rake task, Railtie, tests) pass structured inputs and get structured outputs; they don't need to know about intermediate hash shapes.
- *Tests:* the mapping step gets its own fixtures; the manifest-writing step gets its own. Integration tests shrink to verifying they compose correctly.

---

## Priority given two-day deploy window

| # | Candidate | Pre-deploy? | Status |
|---|-----------|------------|--------|
| 1 | Triplicated symbol extraction | Yes — silent correctness risk | ✅ Done (`46bf129`) |
| 2 | `exclude_paths` divergence | Yes — silent correctness risk | ✅ Done (`0ddd9dd`) |
| 3 | Cache invalidation on identity | Consider — depends on whether multi-configure is used in your app | ✅ Done (`3bfbc76`) |
| 4 | ViewHelpers nil-request fallback | Only if rendering outside a request context | ⏭ Skipped — no non-request renderers |
| 5 | Generator context builder | No — refactor after deploy | 🔲 Pending |
