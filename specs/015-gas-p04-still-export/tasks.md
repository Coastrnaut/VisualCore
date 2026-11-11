---

description: "Task list for feature 015 — Generative Art Studio Phase 04 offscreen still export (ledger gate A01-P04)"
---

# Tasks: Generative Art Studio — Phase 04 Offscreen still export

**Input**: `/specs/015-gas-p04-still-export/`. **Tests** are required:
- host geometry and options tests;
- VisualCoreRendering simulator tests;
- hosted app pixel, determinism and failure tests;
- UI tests on both runtimes;
- the reference regression.

IDs are `T-A01-4##`, with one commit and push per task (`scripts/tick_task.py`).

**Checkpoints**:
- after Phase 1: the API baseline, rules R1–R5 and the reference regression;
- after each phase: `validate_docs.py`.

## Phase 1: Foundational — VisualCore exporter (US3; blocks US1 and US2)

- [X] T-A01-401 [US3] Add `Packages/VisualCore/Sources/VisualCoreScenes/ExportGeometry.swift` with `ExportAspect` — Verified 2026-11-10: VisualCoreScenes/ExportGeometry.swift (ExportAspect with failable init and built-ins square/portrait/landscape/story, ExportSize, ExportGeometry with even rounding, maxEdge/8192/64 MP caps) + ExportGeometryTests 4/4: 12 combinations exact (1080: 1080x1080, 864x1080, 1080x608, 608x1080; 2048 and 4096 rows), caps, pixel cap 8192² → 8000², invalid ratios rejected; run-check A01-P04/t401-visualcore-host swift test exit 0; contract init? noted
  (built-ins `square` 1:1, `portrait` 4:5, `landscape` 16:9, `story` 9:16), `ExportSize` and `ExportGeometry`:
  - long edge = min(longEdge, maxEdge, 8192);
  - short edge = 2 × round(long × short ratio ÷ long ratio ÷ 2), clamped to [2, long];
  - "w × h ≤ maxPixels" (default 64 000 000), scaling down with even edges;
  - `clampedLongEdge`.

  Add `Packages/VisualCore/Tests/VisualCoreScenesTests/ExportGeometryTests.swift`:
  - the 12 combinations exactly (1080: 1080×1080, 864×1080, 1080×608, 608×1080; plus 2048 and 4096);
  - all edges even;
  - caps at maxEdge, 8192 and 64 MP;
  - invalid ratios rejected.
- [X] T-A01-402 [US3] Extend VisualCoreRendering: — Verified 2026-11-10: VisualCoreRendering: RenderCapabilities.maxRenderbufferSize; RenderHost.maxRenderSize (min of texture/renderbuffer/viewport limits), maxOffscreenPixels 64 MP, renderOffscreen(width:height:time:) on the host's own context (size validated before GPU work; registry target released, framebuffer 0 rebound and live resize restored via defer; live sceneFailed untouched); StillImage.swift (StillImage top-down with bottom-up flip, OffscreenRenderError, StillImageEncoder.pngData opaque sRGB via CGImage noneSkipLast + ImageIO). OffscreenExportTests 9/9: exact sizes + top-down quadrants, PNG decode sRGB/no alpha/identical RGB, flip and size validation, live frame identical after export, 8 MiB budget 2048² fails .resource(overBudget) with live counts unchanged and retry OK, scene throw leaves live scene running, invalid sizes refused with no allocation, destroyed host unavailable, maxRenderSize ≥ 4096; run-check A01-P04/t402-rendering-ios27 + ios26 TEST SUCCEEDED
  - `RenderCapabilities.maxRenderbufferSize` (queried from `GL_MAX_RENDERBUFFER_SIZE`);
  - `RenderHost.maxRenderSize` = min(maxTextureSize, maxRenderbufferSize, maxViewport.width, maxViewport.height),
    0 without a context;
  - `RenderHost.renderOffscreen(width:height:time:) throws(OffscreenRenderError) -> StillImage`, following the plan's
    lifecycle contract (validate the size before GPU work; release the target, rebind framebuffer 0 and restore the
    live resize on every path; never change the live `sceneFailed`);
  - in `Sources/VisualCoreRendering/StillImage.swift`: `StillImage` (top-down; init from top-down or bottom-up RGBA;
    `pixel(x:y:)`), `OffscreenRenderError` and `StillImageEncoder.pngData`, which writes an opaque sRGB PNG with
    alpha forced to 255 via CGImage `noneSkipLast` and ImageIO.

  Add `Tests/VisualCoreRenderingTests/OffscreenExportTests.swift`:
  - exact size for 3 sizes;
  - quadrant fixture top-down;
  - every alpha is 255;
  - PNG round trip: same size, sRGB color space name, no alpha, identical pixels;
  - after an export the live frame is identical to the one before;
  - over-budget host (8 MiB) export fails with `.resource` and live counts are unchanged;
  - size above `maxRenderSize` gives `.invalidSize` with no allocation;
  - a destroyed host gives `.unavailable`;
  - `maxRenderSize` ≥ 4096.

  Run on iOS 27.2 and 26.5.
- [X] T-A01-403 [US3] Update the docs: — Verified 2026-11-10: API baseline 838 declarations (+38: ExportAspect/ExportSize/ExportGeometry, StillImage, OffscreenRenderError, StillImageEncoder, RenderHost.maxRenderSize/maxOffscreenPixels/renderOffscreen, RenderCapabilities.maxRenderbufferSize), 0 undocumented; VisualCore README 'Export geometry', VisualCoreRendering README 'Offscreen still export', package map rows (Scenes, Rendering), support-matrix row (A01-P04), known-limitations built note, getting-started module table; run-check A01-P04/t403-deps-api-host 5/5 (docs, dependencies R1-R5, public-api, compliance, host-visualcore); t403-reference-a 3/3 + t403-reference-b 4/4 = reference regression 7/7 (FR-A01-408, SC-A01-405)
  - API baseline (`check_public_api.py --update`);
  - `Packages/VisualCoreRendering/README.md` "Offscreen still export";
  - the VisualCoreScenes README section;
  - `docs/architecture/package-map.md`;
  - `docs/release/{support-matrix,known-limitations}.md`;
  - `docs/getting-started.md` if a module table changes.

  Run R1–R5, the host tests and the reference regression (7 steps) (FR-A01-408, SC-A01-405).

## Phase 2: US1 — Export one full-resolution still (P1) 🎯

- [X] T-A01-404 [US1] Add `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/ExportOptions.swift`: — Verified 2026-11-10: Core ExportOptions.swift (offered long edges 1080/2048/4096, aspect, maxEdge; size via VisualCore ExportGeometry; availableLongEdges clamped + deduplicated; dimensionsLabel; fileName sanitized <name>-<w>x<h>.png, ASCII letters/digits/-/_ kept, others '-', empty 'Untitled', stem ≤ 60; formatLabel 'Opaque · sRGB'); Core depends on VisualCoreScenes; VisualCore ExportSize gained a public init (baseline 839). ExportOptionsTests 4/4 (12 distinct sizes incl. 864×1080 and 1080×608, caps [1080, 2048] at maxEdge 2048 and [1080, 2048, 3000] at 3000, file names, label); run-check A01-P04/t404-core-tests-a2 27/27 pass (a1 failed to compile on the internal ExportSize init, fixed)
  - `longEdge` ∈ {1080, 2048, 4096}, `aspect`, `maxEdge`;
  - `size` via `ExportGeometry`;
  - `availableLongEdges` (clamped, deduplicated);
  - `fileName(for:)`: sanitized `<name>-<w>x<h>.png` (letters, digits, `-`, `_`; others → `-`; empty → `Untitled`;
    at most 60 characters);
  - `formatLabel` "Opaque · sRGB".

  Add the VisualCoreScenes dependency to Core if missing. Add `ExportOptionsTests.swift`: the 12 sizes, the cap at
  maxEdge 2048 giving [1080, 2048], file names, and the label.
- [ ] T-A01-405 [US1] Add `Apps/GenerativeArtStudio/App/ExportSheet.swift`:
  - `ExportRunner`: pause the clock, take time = clock.time, set the particles `displayScale` = h ÷ on-screen point
    height, call `host.renderOffscreen`, then `pngData`, then write `tmp/Exports/<file>`; restore the scale and
    playback;
  - `ExportSheet` with pickers `gas.export.size` and `gas.export.aspect`, `gas.export.dimensions`,
    `gas.export.format`, crop preview `gas.export.preview`, `gas.export.run`, progress `gas.export.progress`,
    `ShareLink` `gas.export.share`, error `gas.export.error`, `gas.export.done`; the file is removed on close.

  Add the Export toolbar button `gas.export` in `SceneScreen.swift`. Add `NSPhotoLibraryAddUsageDescription` "Saves
  exported artwork to your photo library when you choose Save Image." to the app Info.plist in `project.yml`
  (FR-A01-401, FR-A01-403, FR-A01-407, FR-A01-409).
- [ ] T-A01-406 [US1] Add `Apps/GenerativeArtStudio/Tests/Unit/ExportRenderTests.swift`:
  - the 12 combinations decode to the exact dimensions with no alpha and sRGB (SC-A01-401);
  - 2 exports per family are identical (SC-A01-402);
  - a 2× export box-downscaled versus the on-screen render has mean ≤ 6/255 for 4 families (SC-A01-403);
  - particle proportions: the fraction of non-background pixels in a 1× and a 2× particles export differs by
    ≤ 15% relative (FR-A01-406; analyze A1);
  - the Info.plist has `NSPhotoLibraryAddUsageDescription` equal to the clarified text and no other
    `NS*UsageDescription` key (FR-A01-407; analyze C2).

  Run on iOS 27.2 and 26.5.
- [ ] T-A01-407 [US1] Add `Apps/GenerativeArtStudio/Tests/UI/ExportUITests.swift`: open Export; change size and
  aspect, and the dimension label updates (for example "864 × 1080 px"); the format label; run the export; the share
  control appears; close the sheet; the scene is still interactive. The size and aspect pickers expose labels and values (FR-A01-409;
  analyze C3). Run on iOS 27.2 and 26.5.

## Phase 3: US2 — Exports stay within device limits (P1)

- [ ] T-A01-408 [US2] Add to `ExportRenderTests.swift`:
  - a host with an 8 MiB budget fails an export through `ExportRunner` with a readable message, then
    `renderOneFrame` succeeds and live counts are unchanged (SC-A01-404);
  - options never exceed `host.maxRenderSize`;
  - an export on a suspended host (`host.pause()`, as when backgrounded) succeeds or fails cleanly with 0 leaks, and a
    retry after `resume()` succeeds. The export is one synchronous main-actor call, so backgrounding cannot interrupt
    it midway (spec edge case; analyze C1).

  Run on both runtimes.

## Phase 4: Polish

- [ ] T-A01-409 Update `docs/apps/generative-art-studio/visualcore-contract.json` (G-EXPORT closed at A01-P04; M09
  available with renderOffscreen, StillImageEncoder and ExportGeometry evidence) and render it. Run
  `check_app_contract`, the documented API for the app, the release-check fast steps (including compliance and dependency rules: offline, no ProjectM; analyze C3) and the
  Phase 03 library tests
  (FR-A01-410, SC-A01-405).

## Dependencies

T-A01-401 → T-A01-402 → T-A01-403 → T-A01-404 → T-A01-405 → T-A01-406 and T-A01-407 → T-A01-408 → T-A01-409.

## Implementation strategy

The VisualCore exporter first (Principle II), then the domain options, the UI, the pixel tests, the limits, and the
contract.

## Analyze remediation (2026-11-10)

Applied autonomously (CLAUDE.md §2): C1 → T-A01-408 suspended-host export; C2 → T-A01-406 usage-string check;
C3 → T-A01-407 accessibility values, T-A01-409 compliance; I1 → research R7 wording; A1 → T-A01-406 particle measure.
0 critical issues.
