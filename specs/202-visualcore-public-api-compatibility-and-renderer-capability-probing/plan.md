# Implementation Plan: R02-F02 — public API compatibility and renderer capability probing

**Branch**: spec directory only, work on `main` | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Extend the renderer's existing report (`RenderCapabilities`) with optional values for multisampling, draw buffers,
colour attachments, vertex limits, vertex and integer precision, EGL version and extensions, the missing-entry-point
count and the context generation; take it again on every context recreation and fail the host when a reload misses
entry points; add a pure floor check; carry a typed, optional renderer record into the verification evidence. All
additions are optional fields, so stored reports and evidence keep decoding. No window configuration change.

## Technical Context

**Language/Version**: Swift 6.4.2, Xcode 27.2 (27B52); C bridge already tracked. Python 3 for the evidence validator.
**Primary Dependencies**: VisualCoreRendering (`RenderCapabilities`, `RenderHost`), VisualCoreExperience
(`EvidenceRecord.Environment`, `EvidenceRecord.observed`), VisualCoreExperienceHost (`ExperienceSession.renderHost`),
the app's `ScenarioLaunch`; `scripts/check_evidence.py`.
**Storage**: evidence JSON (`environment.renderer`, optional). Report schema: optional fields only, no version bump.
**Testing**: pure host tests (`swift test --package-path Packages/VisualCore`), rendering package tests on sim-27.2 and
sim-26.5, one verification run, script tests, the reference regression in two chunks.
**Target Platform**: iOS 26.0+, simulators now; device values in the device campaign.
**Constraints**: GL calls only on the render thread with the context current (constitution III); no window MSAA or
depth (ADR-0002); tests short.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Proven renderer only | Queries only; no new renderer, no window config change | pass |
| II App-neutral public API | Additive optional fields; documented; baseline updated | pass |
| III GPU lifecycle and threads | Query runs inside `RenderHost` init and `recreateContext`, where the context is current | pass |
| IV Host-testable logic | Floor check and the renderer record are pure and host-tested | pass |
| V Implementation before devices | Device values deferred to the campaign | pass |
| VI Evidence over assertion | Every value recorded as reported; floor findings recorded, not hidden | pass |
| VII Native accessible UI | No UI | n/a |
| VIII Public APIs, privacy | GL/EGL queries only; no identifiers beyond renderer strings (renderer/vendor names, no device serials) | pass |
| IX Bounded untrusted input | Decoding stays tolerant of missing fields; validator rejects malformed `renderer` | pass |
| X Licensing | Constants from tracked declarations | pass |
| XI One app | No target change | pass |
| XII One purchase, no ads | Not touched | pass |
| XIII Code-driven visuals | Not touched | pass |

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderCapabilities.swift   modify  new optional fields, queries, generation, floorFindings()
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderHost.swift            modify  re-query on recreateContext; reload missing count → typed failure
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderCapabilitiesProbeTests.swift  new  floors, absent values, recreate refresh, old report decodes
Packages/VisualCore/Sources/VisualCoreExperience/RendererRecord.swift               new     pure Codable record (optional strings and ints)
Packages/VisualCore/Sources/VisualCoreExperience/EvidenceRecord.swift               modify  Environment.renderer: RendererRecord? (key "renderer")
Packages/VisualCore/Tests/VisualCoreExperienceTests/RendererRecordTests.swift        new     round trip, old evidence decodes
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/RendererRecord+Capabilities.swift  new  RenderCapabilities → RendererRecord
Apps/VisualCore/App/Automation/ScenarioLaunch.swift                                  modify  fill environment.renderer from the session's host
scripts/check_evidence.py, scripts/tests/test_evidence_renderer.py                   modify/new  optional renderer validated
Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md, docs/api/visualcore-public-api.txt  modify
```

Dependency direction unchanged: VisualCoreExperienceHost depends on both packages and does the mapping (rule R2).

## Commands

`swift test --package-path Packages/VisualCore`; `xcodebuild_package.py --package Packages/VisualCoreRendering
--scheme VisualCoreRendering-Package --destination sim-27.2|sim-26.5 --action test`; `verify_experiences.py --only
a01.generative-art-studio --runtime 27 --scenario launch-first-frame`; `check_public_api.py --update`;
`check_documented_api.py --sources Apps/VisualCore`; the two reference chunks of `release_check.py`.

## Rollback

Additive, separate commits; `git revert` restores the previous report and evidence schema; stored files stay readable
either way.
