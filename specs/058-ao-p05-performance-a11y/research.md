# Research: A07-P05 (feature 058)

## 0. Verified facts (2026-11-14)

- The host passes a quality tier index to the presenter's draw; A06 overrides it with `forceTierForTesting`.
- `ResourceRegistry.stats` returns a ledger snapshot; `AnnouncementSink.announce(_:)` posts an announcement;
  `MeshBudget(maxVertices:maxIndices:)` and `SegmentWindow` exist; `CameraRail.pose(at:)` wraps the distance.
- `Catalog/registrations.json` records `quality_tiers` per experience (A06: level-0/1/2).

## 1. Decisions

- **D1 StreamingBudget:** levels with behind/ahead/drawDistance/elementShare, validated non-increasing; vertex check per
  level against a `MeshBudget`. Alternative: reuse `QualityLevel` shares only (no window semantics).
- **D2 Levels for A07:** ahead 8/6/4, behind 2/2/1, draw distance 110/80/50, element share 1/0.6/0.35.
- **D3 Precision fixture:** rail wrap + Double distance + rebased Float drawing; tests at 10^9.
- **D4 Long session:** 3,600 frames offscreen at 64 × 64 points; ledger snapshot equality after the first window;
  extrapolation by arithmetic (constant per-frame work).
- **D5 Announcer:** `JourneyAnnouncer` (1.5 s, changed text, latest pending) in Core; sink calls only when VoiceOver runs.
