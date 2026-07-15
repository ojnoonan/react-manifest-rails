# Hands-free bundles: auto-promotion + internal manifests

- **Date:** 2026-07-15
- **Status:** Approved (design) — pending implementation plan
- **Target:** minor version bump (behavior change; changelog note required)

## 1. Context & problem

The gem generates one lean `ux_<controller>.js` per controller plus a shared
`ux_shared.js`. A page loads `ux_shared` + (optionally `always_include` bundles) +
the controller bundle.

Today, when a component defined under `ux/app/<controller>/` is used by *another*
controller, the generator **inlines that component's file into every consumer's
manifest** (cross-app dependency detection). This is correct in isolation, but when
two of those bundles land on the same page — the classic case being a navbar bundle
in `always_include` co-loading with the current page's controller bundle — the same
global `const` is concatenated twice.

Observed failure (real report that motivated this work):

- `ExportForm` / `TableSettingsForm` live in `ux/app/common/`; a `Show` component
  lives in `ux/app/notification/` and is rendered by the navbar.
- `always_include` carries the navbar bundle onto every page.
- Result: `ExportForm`, `Show`, etc. are inlined into `ux_navbar` **and** each
  consuming controller bundle. On any page that renders the navbar, the browser
  throws `Uncaught SyntaxError: Identifier 'ExportForm' has already been declared`
  at the component's own source position.
- Because a `SyntaxError` aborts the entire concatenated script, everything after it
  never executes — so genuinely-shared symbols (e.g. `IconComponent`, which *is* in
  `ux_shared`) surface as `X is not defined`. The two symptoms share one root cause.

Regenerating manifests never fixed it because the manifests were *correct for the
current design* — the duplication is a property of the emission strategy plus file
placement, not a stale-file problem.

A second, smaller pain: the generated `ux_manifests/*.js` files are committed to git.
They are a deterministic build artifact (regenerated on every dev boot and before
every precompile), so committing them clutters diffs and invites manual edits.

## 2. Goals / non-goals

**Goals**

1. A component may be defined under `ux/app/<controller>/` and used by any number of
   other bundles **without** ever being declared twice on a page — with no manual
   file moves.
2. Preserve lean controller bundles for genuinely private code.
3. Stop generated manifests from cluttering git and from being dev-editable, while
   keeping production correct.

**Non-goals**

- No runtime/in-memory bundle synthesis (rejected: fragile against Sprockets 4
  internals; complicates digests/caching).
- No source rewriting / no wrapping definitions in idempotency guards.
- No change to the `react-rails` integration surface (`react_bundle_tag`,
  `react_component`) beyond what falls out of correct manifests.

## 3. Feature 1 — Auto-promotion of shared components

### 3.1 Invariant

> **Every source file is emitted into exactly one bundle.** For any page, a file
> appears in `ux_shared` **or** exactly one controller bundle — never both, never in
> two controller bundles that can co-load.

### 3.2 Promotion rule

A controller-owned file is **promoted** to `ux_shared` when either:

1. **Direct external use** — a symbol it defines is used by a file whose owning
   bundle differs from the file's owner (another controller, or an `always_include`
   bundle, or a shared-dir file). *A shared-dir file referencing a controller symbol
   also triggers promotion* — shared code loads on every page, so anything it needs
   must too.
2. **Transitive need** — it is depended on (via symbol usage) by an
   already-promoted file. Promotion is closed to a fixpoint over the
   controller-dir dependency graph.

Files used only within their owning controller are **not** promoted; they stay in
that controller's bundle.

### 3.3 Algorithm

Computed in `Generator#build_controller_context` (which already builds the symbol
graph). New/changed data:

- `symbol_to_file` — for each controller-owned symbol, the absolute path of its
  defining file. (Today only `symbol_to_bundle` exists; promotion needs file
  granularity.)
- `promoted_files` — a `Set` of absolute paths.

Procedure:

```
seed = {} 
for each controller file F (owner B):
  for each symbol s defined in F:
    if s is used by any file in a bundle != B  (or by a shared-dir file):
      seed << F

promoted = transitive_closure(seed):
  worklist = seed
  until stable:
    for each promoted file P:
      for each symbol u used by P:
        D = symbol_to_file[u]        # defining controller file, if any
        if D present and D not promoted: promote D
```

- Isolated dirs (`config.isolated_app_dirs`) never register symbols into the shared
  index, so their files can never be seeded and are never promoted. (Unchanged
  guarantee: isolated dirs never leak.)
- Determinism: `promoted_files` is materialized sorted; a symbol defined in two
  files keeps the existing first-writer rule so results are stable across runs.

### 3.4 Emission changes

- `build_shared(shared_dirs)` → requires = files from shared dirs **+**
  `promoted_files`, `uniq`, sorted. (Promoted files stay physically in their
  `ux/app/...` location; only the `//= require` line lives in `ux_shared.js`.)
- `build_controller(ctrl)` → requires = the controller's own files **minus**
  `promoted_files`, plus `external_requires`. 
- `build_always_include_requires` → the always-include set **minus**
  `promoted_files` (else a promoted file would sit in `ux_shared` *and* the
  always-include set → duplication).

### 3.5 Removed logic

The current cross-app inline path — `controller_dependency_requires` and the
`transitive_dependencies` walk *used for controller emission* — is removed: every
cross-bundle dependency is now satisfied by promotion to `ux_shared`. The dependency
graph is still computed and exposed for `react_manifest:analyze` / `DependencyMap`
reporting.

### 3.6 Config & rollout

- **Default on.** No configuration required for the hands-free path.
- Escape hatch: `config.auto_shared` (default `true`). When `false`, restore the
  prior inline behavior verbatim (backward-compatible output).
- Minor version bump; `CHANGELOG` entry: "`ux_shared` now includes `app/` components
  that are used across bundles (auto-promotion). Set `config.auto_shared = false` to
  restore inlining."

### 3.7 Reporting

`react_manifest:analyze` gains a **Promotions** section listing each promoted file
and the bundles that forced it (e.g. `ux/app/notification/show_component → promoted
(used by: ux_navbar)`), so routing is never mysterious and a heavily-shared
component can be relocated by hand if desired.

### 3.8 Interactions summary

| Concern | Behavior |
|---|---|
| `isolated_app_dirs` | Never promoted; stays in its own bundle. |
| `external_roots` / `external_providers` | Unchanged — external symbols are emitted as external requires, not promoted (they are not controller-owned files). |
| `always_include` | Kept. Private files of an always-include bundle still load everywhere; its cross-used files are promoted and excluded from the always set. |
| Shared-dir file using a controller symbol | The controller file is promoted (previously only warned about). |

## 4. Feature 2 — Internal (gitignored) manifests

Chosen: **Approach A — gitignore in place.** No asset-pipeline changes; the
`link_tree` directive and generation location are untouched.

- Generator continues writing to `app/assets/javascripts/ux_manifests/`.
- `react_manifest:setup`:
  - Idempotently appends `app/assets/javascripts/ux_manifests/*.js` to the app's
    `.gitignore` (skip if already present).
  - Ensures `app/assets/javascripts/ux_manifests/.keep` exists (so the directory is
    present on a fresh clone before first generation — avoids any
    `link_tree`-on-missing-dir edge case). `.keep` is committed; `*.js` is not.
  - Prints (does **not** run) the one-time untrack command:
    `git rm --cached app/assets/javascripts/ux_manifests/*.js`. The gem never mutates
    the user's git history.

### 4.1 Production safety

Verified with the user: the deploy runs `assets:precompile`. The Railtie already
enhances `assets:precompile` with `react_manifest:generate`
(`railtie.rb`), so manifests are regenerated from the committed `ux/` source before
Sprockets compiles them. Production serves the digested `public/assets/` output; it
never reads the source manifests at request time. Therefore the manifests do not need
to be committed — they are a build artifact analogous to `public/assets/`.

Boot-time generation remains development-only; production relies solely on the
precompile hook (correct: no prod process writes into the app dir at boot).

## 5. Testing plan (comprehensive, edge cases first-class)

Tests use the existing fixture harness (`with_temp_rails_root { }`, FakeRails). New
fixtures under `test/fixtures/dummy/.../ux/` model the scenarios below.

### 5.1 Promotion — inclusion / exclusion

1. **Private component** — used only by its owner → **not** promoted; appears only in
   the owner's controller bundle, absent from `ux_shared`.
2. **Cross-controller use** — `A` defines `Widget`, `B` uses `Widget` → `Widget`'s
   file promoted to `ux_shared`, absent from both `ux_A` and `ux_B`.
3. **Used by `always_include` bundle** — component used by the navbar bundle →
   promoted.
4. **Shared-dir file references a controller symbol** — a `ux/lib` file uses a
   controller-owned `Foo` → `Foo`'s file promoted (not merely warned).

### 5.2 Promotion — transitive closure

5. **Depth-1 transitive** — promoted `A` uses `B` (B private to A's dir) → `B`
   promoted too.
6. **Chain depth ≥3** — `A → B → C` all in controller dirs, `A` externally used →
   `A`, `B`, `C` all promoted.
7. **Cycle** — `A` uses `B`, `B` uses `A`, one externally used → both promoted, no
   infinite loop (fixpoint terminates).
8. **Diamond** — `A` and `B` both depend on `C` → `C` promoted exactly once (single
   `//= require`, no duplicate directive).

### 5.3 Single-emission invariant (property tests)

9. For a representative fixture app, assert: **no** `//= require` path appears in both
   `ux_shared` and any controller bundle.
10. Assert: **no** require path appears in two different controller bundles.
11. Assert: no require path appears twice within any single manifest.

### 5.4 Regression — the reported bug

12. Fixture: `ux/app/common/{export_form, table_settings_form}`,
    `ux/app/notification/{notifications_index, show_component}`,
    `ux/app/navbar/navbar` (uses `Show`, `ExportForm`), `always_include = ["ux_navbar"]`.
    - Assert `export_form`, `table_settings_form`, `show_component` are in
      `ux_shared` **only**.
    - Assert `ux_navbar` and `ux_notification` contain none of them.
    - Simulate the notification page's bundle set
      (`ux_shared` + `ux_navbar` + `ux_notification`) and assert each promoted file's
      require appears exactly once across the union.
13. Assert notification-*specific* files (`notifications_index`) stay in
    `ux_notification` — promotion does not over-hoist a controller's private code.

### 5.5 isolated_app_dirs

14. Component in an isolated dir, referenced by name elsewhere → **not** promoted;
    stays in its own bundle; never appears in `ux_shared`.

### 5.6 external_roots / external_providers

15. Symbol provided via `external_roots` used by a controller → emitted as an external
    require, **not** promoted; behavior identical to pre-feature.
16. `external_providers` mapping still wins on symbol conflicts.

### 5.7 always_include

17. Always-include bundle's **private** file (used only by it) → present in every
    controller's always set, not promoted, no duplication.
18. Always-include bundle's **cross-used** file → promoted, excluded from the always
    set (not in both `ux_shared` and always set).
19. On the always-include bundle's **own** controller page → not double-loaded
    (existing bundle-level dedup still holds).

### 5.8 Backward compatibility

20. `config.auto_shared = false` → output matches pre-feature generation exactly
    (cross-deps inlined, nothing promoted, no files added to `ux_shared`). Guards the
    escape hatch.

### 5.9 Determinism / idempotency

21. Promotion set identical across repeated runs (sorted output).
22. Regenerating twice yields `:unchanged` (digest stable) — promotion introduces no
    nondeterminism.

### 5.10 Extractor parity (AST vs regex)

23. With and without `mini_racer`, a clear cross-use case promotes identically
    (promotion consumes the same `SymbolExtractor` output; guards against divergence).

### 5.11 Edge / empty

24. No controllers → `ux_shared` = shared dirs only; empty `promoted_files`; no error.
25. Controller dir with no files → empty controller bundle handled (existing "no JSX
    files found" comment path).
26. Symbol collision across two controller files → deterministic owner; promotion
    deterministic; no duplicate require emitted.

### 5.12 Feature 2 — internal manifests

27. `react_manifest:setup` appends the `.gitignore` pattern; running it twice does
    **not** double-append (idempotent).
28. `.keep` created and the directory exists after setup.
29. Generator still writes `*.js` to the same location; `link_tree` directive
    unchanged.
30. Fresh-clone simulation: directory contains only `.keep`, no `*.js` → generation
    (boot/precompile path) produces the manifests and they resolve.
31. The one-time `git rm --cached` command is **printed**, and the task performs no
    git mutation itself.

## 6. Risks & mitigations

- **`ux_shared` growth** — accepted by design (correctness over payload for shared
  code); private code stays lean. The `analyze` promotions report gives visibility.
- **`link_tree` on a fresh clone before first generation** — mitigated by committing
  `.keep` so the directory always exists; generation precedes asset compilation in
  both dev (boot) and prod (precompile hook).
- **A deploy that skips `assets:precompile`** — out of scope; user confirmed
  precompile runs. Documented as the precondition for gitignoring.
- **Behavior change for other gem users** — mitigated by the minor bump + changelog +
  `config.auto_shared = false` escape hatch.

## 7. Open questions

None blocking. Possible future work: auto-promotion could later gain a
"co-load-aware" mode that only promotes when two consumers can actually appear on the
same page (finer leanness), but the current simple rule was chosen deliberately.
