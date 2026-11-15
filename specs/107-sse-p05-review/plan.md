# Implementation Plan: Solar System Explorer — Phase 05 Scientific review and device QA

**Branch**: `107-sse-p05-review` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-REVIEW with no VisualCore change: in the core `EventChecks` (four Mars oppositions, three Earth perihelia,
±3 days, sources), the model statement and `ScientificReview.markdown()` generating
`docs/apps/solar-system-explorer/scientific-review.md` (compared by a test), and a 72-state labelling test; in the
experience two detail levels (`SolarCore.qualityTiers` 2; the presenter draws level 1 with 24 × 12 spheres, 200 stars
and 64-sample orbits, all built once), the registration's `quality_tiers` and its fixture copy, an "About this model"
text in the controls, and `docs/apps/solar-system-explorer/device-campaign.md` with {device} tasks. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/review.md](contracts/review.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified during clarification): `ExperiencePresenter.draw(_:tier:context:
frame:)` receives the host's level; `Core.qualityTiers` names the levels (`qualityProfile`); `Catalog/registrations.json`
`quality_tiers`; `CitationAudit.markdown`; `OrbitModel`, `SimulatedDate`, `SolarCore.canvasDescription`. **Storage**:
none. **Testing**: ExperiencesCreative SSE tests on sim-27.2; VisualCore experience tests that read the registration
fixture (`RealCatalogTests` in the app, the VisualCore catalog fixture test); app build and unit; runner iOS 27;
packages; contract; documented API; script tests. **Performance**: level 1 halves vertices, stars and orbit samples.
**Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A14. No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (no new framework code) · II-a N/A · III PASS (no assets) · IV PASS (events, review, labelling tested
without GPU; levels tested through frames) · V PASS (no state change; registration updated with its fixture) · VI PASS
· VII PASS (model statement shown and spoken; truthful labels proven over the state space) · VIII PASS · IX PASS (lower
level for memory, heat and low power) · X PASS (device QA deferred, planned) · XI–XIII PASS. A14 rules: provenance of
every number (review document), truthful claims, deterministic core — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{EventChecks,ScientificReview}.swift                    new
Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{EventChecksTests,ScientificReviewTests,
  TruthfulLabelTests}.swift                                                                                  new
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{Adapter/SolarCore,SceneMeshes,SolarPresenter,
  SolarControls}.swift                                                                                       modify
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/SolarQualityTests.swift                     new
Catalog/registrations.json; Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/
  registrations.json (quality_tiers)                                                                         modify
docs/apps/solar-system-explorer/{scientific-review.md (generated), device-campaign.md, visualcore-contract.json
  (G-REVIEW closed), visualcore-contract.md, README}                                                         new/modify
```

**Lifecycle**: unchanged; the presenter keeps both levels' CPU meshes and makes every renderer of both levels together
(shared program, A14-P01 As built), choosing by `tier` per frame. **Migration**: none (no state change). **Rollback**:
revert the commits.

## Parallel work

Agent A: `EventChecks`, `ScientificReview` and their tests, the labelling test. Lead: qualityTiers, registration,
presenter levels and the quality test, the controls text, device campaign, contract, runs.

## Evidence

`run-check --stage A14-P05`: `sse-ios27`, `visualcore-catalog` (the VisualCore catalog fixture test), `app-unit`,
`verify-27`, `experience-packages`, `script-tests`, `contract`, `visualcore-docs`.
