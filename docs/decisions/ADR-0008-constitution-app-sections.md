# ADR-0008 — Constitution 1.3.0 and 1.4.0: app-scoped sections for A02 and A03

**Date:** 2026-11-11 · **Status:** accepted (`/speckit-constitution` at gates A02-P00 and A03-P00, owner standing
delegation)

## Context

Each app's Phase 00 runs its manual's `/speckit-constitution` prompt. ADR-0007 decided that each app appends its own
subsection under **App-Scoped Rules**, never replacing the suite principles. The 1.3.0 amendment (A02 Fluid Art
Playground) was committed without its own decision record; this ADR records it alongside 1.4.0.

## Decision

- **1.3.0 (MINOR)** adds **A02 Fluid Art Playground**: the isolated solver with a CPU reference, an artistic model
  that makes no accuracy claims, bounded GPU (quality profile, clamped Δt, no read-write of one texture), and
  gesture alternatives.
- **1.4.0 (MINOR)** adds **A03 Fractal Explorer**, from the manual's prompt, with suite-level reuse:
  - generic complex-plane viewport, precision, palette, camera, bookmark and capture machinery goes to VisualCore;
  - truthful precision: zoom is clamped where float32 stops being reliable and the limit is shown; no
    unlimited-deep-zoom or scientific claims; device-measured limits before any compatibility claim;
  - a render-cost estimate before expensive work;
  - Reduce Motion for palette animation and tours.

The suite principles I–X are unchanged. The manual's separate-repository advice is again replaced by the monorepo
layout (CLAUDE.md §4).

## Consequences

The A03 Phase 00 audit maps each manual component to a VisualCore owner or a recorded gap. Later apps keep
appending one subsection per app with a MINOR bump and a line in this ADR series.
