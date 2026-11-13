# Research: UA-F11 — Privacy, licensing, no-advertising audit and distinctiveness

**Date**: 2026-11-13 · **Spec**: [spec.md](spec.md)

## 0. Read-only audit of the named sources (2026-11-13)

Every name below was opened in the current source; line numbers are from `main` at `45a31b5`.

| Source | Verified facts |
|---|---|
| Auto-Creator.md §15.2, §15.4 | One manifest audited against the built app; usage descriptions only for capabilities of registered experiences; no analytics, tracking, advertising identifier or third-party SDK; ANGLE notices bundled and shown; ProjectM never linked; distinctiveness matrix over all pairs of the 100 launch experiences, six Round 2 close pairs first; near-duplicates redesigned (D-16); names, trademarks, age rating are owner reviews. |
| `scripts/check_privacy_manifest.py` (135 lines) | `--app` (required), `--json`; `scan()`, `compare()`, `binaries(app)` (main executable plus embedded frameworks), `collect()` via `nm` and `strings`. Already a release-check step `app-privacy-manifest` on the Release app (`release_check.py:286`). Self-tests live in `scripts/test_scripts.py`. Its JSON has no revision or executable digest. |
| `scripts/check_licenses.py` (86 lines) | `--root`, `--inventory`; maps `.binaryTarget`, remote and local packages of every `Package.swift` and the `packages:` of `project.yml` to `docs/legal/third-party.json`. No `--app` mode. Release-check step `licenses`. |
| `scripts/bundle_licenses.py` (92 lines) | `bundle(inventory, out, root)`; `--out`, `--inventory`, `--root`; writes `licenses.json` plus `<id>.txt` for `scope: shipped`; `GENERATED` table. Runs as the app's post-build script "Bundle licenses (UA-F04)" (`project.yml:243`). |
| `docs/legal/third-party.json` | schema 1; shipped: visualcore, angle and nine ANGLE sub-components; harness-only: projectm, glad, glm and others. |
| `scripts/check_release_symbols.py` (127 lines) | `--app`, `--forbid TEXT…`, `--expect-present`; `binaries(app)`, `forbidden_hits()` over `nm` output and raw bytes. Release-check step `app-release-symbols`. |
| `scripts/check_compliance.py` (116 lines) | `RULES` list (ReplayKit, private frameworks, dlopen/dlsym, string dispatch, direct Metal), `PROJECTM`, `NETWORK`, `SIGNING`, `BACKGROUND`; scans `Packages`, `Apps`, `Showcase`, `Harnesses`, `Bridging`. No advertising or tracking rule. |
| `scripts/audit_showcase_dependencies.py` (288 lines) | `--target`, `--sources`, `--app`, `--symbols-file`, `--skip-packages`, `--json`; `DENY_TEXT` (projectm, milkdrop, presetlibrary, …), `ALLOWED_PATH` (ANGLE libEGL/libGLESv2 only), `audit_binary()`. Runs in the app's post-build "Dependency audit" with `--target VisualCore`. |
| `Catalog/registrations.json` | schema 1, `registrations` keyed by experience id; entry keys exactly `capabilities`, `quality_tiers`, `palette`, `content` plus optional `manifest` (`build_catalog.py:50,85-110`). `manifest` does not enter the runtime catalog; the same pattern serves `permissions`. |
| `Apps/VisualCore/Generated/Info.plist`, `project.yml:202` | One usage key, `NSPhotoLibraryAddUsageDescription` ("Saves exported artwork to your photo library when you choose Save Image."). |
| `VisualCoreUI.AcknowledgementsView`, `LicenseInventory` | Loads `Licenses/licenses.json` from the main bundle; rows identified `<prefix>.<entry id>`, text `<prefix>.text`. `AboutView.swift:39` opens it through `ShellID.aboutAcknowledgements` (`vc.about.acknowledgements`). No app interface test opens it. |
| `docs/catalog/experience-catalog.json` | 300 experiences, 100 with `release: launch`. Design fields: A01–A25 `primary_capability`, `summary`; R02 `core_abstraction`, `roster_core_action`, `controls`, `victory`; R03/R04 `core_abstraction`, `player_action`, `win_predicate`. Each experience has `launcher_category`, `order`, `tier`, `name`, `slug`. |
| `.autonomy/migration/ledger.json` | Gate objects with `id`, `kind`, `status`; experience gates `X-<code>` (X-A01..X-A03 pass). Only `migration_ledger.py` writes it; readers are listed in `test_scripts.py` `LEDGER_READERS`. |

Not existing (to be created): an advertising/tracking scan, a permission vocabulary, a usage-description check for the one
app, a built-app license assertion, a distinctiveness generator or matrix, a metadata-input generator, a game-title list.

Corrections to the audit note `Build/agent-notes/UA-F11-audit.md`: none; every cited name exists or is absent as stated.

## 1. Decisions

### D1 — Tracking scan as its own tool
- **Decision**: new `scripts/check_no_tracking.py` with a versioned deny list `Configs/tracking-denylist.json`, reusing the
  binary enumeration pattern of `check_release_symbols.binaries()` (imported, not copied). Linked libraries via
  `otool -L`, symbols via `nm -m`, bundled files by bytes; fixtures through `--symbols-file`/`--libraries-file` like
  `audit_showcase_dependencies.py`.
- **Rationale**: `--forbid` alone cannot check linked frameworks and has no allow-list with reasons (FR-U11-023).
- **Alternatives**: extending `check_release_symbols.py` (mixes debug-only symbols with policy); source scan only
  (proves nothing about the built app).

### D2 — Source rule
- **Decision**: add one rule to `check_compliance.py` `RULES`: imports of `AdSupport` or `AppTrackingTransparency`,
  `ASIdentifierManager`, `ATTrackingManager`, `advertisingIdentifier`.
- **Rationale**: fails before a build (story 3 scenario 3).

### D3 — Permissions in registrations
- **Decision** (clarification 1): optional `permissions` key in each registration, validated by `build_catalog.py`
  against `Configs/permission-vocabulary.json` (schema 1, word → usage key); it does not enter the runtime catalog.
  `scripts/check_usage_descriptions.py` compares the union with the usage keys of `Apps/VisualCore/Generated/Info.plist`
  (default) or a built app's `Info.plist` (`--app`).
- **Rationale**: no Swift API change; one source of truth beside the other registration facts.
- **Alternatives**: a Swift `ExperienceDescriptor.permissions` field (public API change for a build-time fact);
  per-app `release.json` (one app has no such file).

### D4 — Built-app license assertion
- **Decision**: `check_licenses.py --app <app>` additionally compares `<app>/Licenses/` with `bundle()`'s expected
  output for shipped entries, byte for byte.
- **Rationale**: reuses the inventory reader; one tool per concern.

### D5 — Distinctiveness
- **Decision** (clarifications 2 and 3): `scripts/check_distinctiveness.py` generates
  `docs/legal/distinctiveness-matrix.json` (rows for 4,950 pairs) and `docs/legal/distinctiveness-matrix.md` (summary:
  close pairs, top 20 scores, counts); `--check` regenerates in memory and compares bytes, then applies the verdict
  rule. Names checked against `Configs/known-game-titles.json`. Jaccard threshold 0.5; highest launch pair today 0.375
  (A23/A25), measured 2026-11-13.
- **Rationale**: deterministic, catalog-only, short (4,950 set comparisons run in well under a second).
- **Alternatives**: embeddings or web lookups (not deterministic, need a model or network; forbidden).

### D6 — Metadata inputs
- **Decision**: `scripts/metadata_inputs.py` writes `docs/release/metadata-inputs.json` from the ledger's pass `X-` gates
  and the catalog; privacy answers are filled only when `--privacy-report` and `--tracking-report` name passing
  reports of the same executable digest, else `"unproven"`. `--check` compares the file with the ledger.
- **Rationale**: UA-F14 consumes it; no App Store Connect access.

### D7 — Report metadata
- **Decision**: new `scripts/report_meta.py` with `meta(app=None)` → `{schema, revision, clean, configuration,
  executable_sha256}`; every new tool and `check_privacy_manifest.py --json` include it (clarification 5).

### D8 — Where checks run (clarification 4)
- Release check: all checks; the built-app ones after `app-release-build`.
- CI `checks` job (Linux): `check_compliance.py`, `check_usage_descriptions.py`, `check_distinctiveness.py --check`,
  `check_licenses.py`. CI `app-build` job (macOS, stand-in ANGLE): `check_no_tracking.py`, `check_licenses.py --app`
  on the Release build. The ProjectM audit already runs in every app build's post-build phase.
- `metadata_inputs.py --check` runs in the release check only (the ledger changes when an X gate is recorded).

### D9 — Acknowledgements interface test
- **Decision**: new `Apps/VisualCore/Tests/UI/AcknowledgementsUITests.swift` opens About → Acknowledgements and asserts
  one row per shipped inventory entry (ids read from `docs/legal/third-party.json` through the test file's path on the
  simulator host) and that a row opens readable text. One pass on the iOS 27.x phone (owner ruling).

### D10 — No VisualCore package change
- No public API changes, so the API baseline, documented-API and ProjectM regression steps are not triggered; the
  quickstart keeps them as conditional commands.

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

Round 1: 0 critical, 2 high, 2 medium, 2 low. Fixed under the owner's delegation:
- A1 (high): FR-U11-012 now requires the property-list text to equal the vocabulary's text (data-model §1 gains `text`).
- A2 (high): deny-list library names are distinctive module identifiers of at least 6 characters, matched whole
  (data-model §3, T-U11-013), so common words such as "Adjust" or "Branch" never match.
- C1 (medium): `--json` added to the distinctiveness, metadata-input and built-app license contracts and tasks (FR-U11-080).
- C2 (medium): every new tool's tests refuse a schema-2 input and a missing input (T-U11-002, FR-U11-081).
- C3, U1 (low): FR-U11-033 and FR-U11-072 are rule constraints without own tasks; the missing-build test is in T-U11-002.
Round 2: 0 critical, 0 high, 0 medium; 39 of 39 buildable requirements and 8 of 8 success criteria have tasks.
