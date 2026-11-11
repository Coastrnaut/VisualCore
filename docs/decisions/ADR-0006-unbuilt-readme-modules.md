# ADR-0006 — README modules not built in the foundation (audio, controllers, test support, UI, asset metrics)

**Date:** 2026-11-10 · **Status:** accepted (autonomous decision under the owner's standing approval, CLAUDE.md §2)

## Context

The README layout lists ten packages. The audit asked whether all are covered. ADR-0003 and the package map
consolidate them into two SwiftPM packages and map every entry. However, no foundation feature (F00–F09)
schedules the audio taps/DSP, game-controller input, a shared TestSupport image-baseline module, the SwiftUI
`VisualCoreUI` surface or asset metrics. Their modules exist only as placeholders.

## Decision

1. Do not claim them in 1.0.0-rc.1. `docs/release/known-limitations.md` and `support-matrix.md` list each one as not
   implemented.
2. Build each one in the first app phase whose manual requires it, as a shared module (not app-local code):
   - audio in A06–A08;
   - controllers in A10 if its manual calls for them;
   - TestSupport baselines when a second consumer needs pixel baselines;
   - UI and asset metrics when first needed.

   That app phase's spec traces the work back to the README entry and to this ADR.
3. Audio source claims still need the ten-minute non-silent real-device diagnostic (CLAUDE.md §5).

## Alternatives considered

- **Add a new foundation feature now:** rejected. The ledger fixes ten foundation gates (ADR-0004), and building audio
  without its first consumer risks an unused API.
- **Leave it undocumented:** rejected. It would over-claim the release.

## Status update (2026-11-10, after A01-P01)

The following were built as shared modules in feature 012:
- `VisualCoreParameters` (new);
- `VisualCoreUI.RenderSurface`;
- `VisualCoreTestSupport` image comparison;
- `VisualCoreRendering` `ShaderBundle`, the GLSL library and `FullScreenShaderScene`.

Still open:
- audio (A06–A08);
- controllers;
- the TestSupport fake clock and fixtures;
- the VisualCoreUI accessibility settings model and diagnostics overlay;
- asset metrics.

