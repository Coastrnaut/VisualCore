# Implementation Plan: Oscilloscope Studio — Phase 05 Device-route and accuracy audits

**Branch**: `065-os-p05-routes-accuracy` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-STEREOMIC in `VisualCoreAudio`: `StereoMicrophoneAudioSource` with the internal `StereoMicrophoneCapture` seam
(`SystemStereoMicrophoneCapture` taps channels 0 and 1, or duplicates channel 0) and the mono source's permission,
interruption and route handling. Close G-ACCURACY and G-MEASUREA11Y in the experience: `ScopeAccuracyAudit` (cases of
clarification 2 through the real path, an `AccuracyReport`), `ScopeAnnouncer` (1.5 s, VoiceOver only), description
coverage for every view and state, and `ScopeQuality` (levels 0/1/2: columns 1, ½, ¼; analysis every 1, 2, 4 frames)
with `ScopeCore.qualityTiers = 3`; the scope's microphone switches to the two-channel source; registration
`quality_tiers` level-0/1/2; manifest fixture for the frozen capture's metadata; `docs/apps/oscilloscope-studio/
device-campaign.md` started with route, latency, rate and thermal items. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A08-P04 plus `VisualCoreUI` (`AnnouncementSink`). **Storage**: unchanged
(schema 3). **Testing**: `VisualCoreAudioTests` on sim-27.2 (`StereoMicrophoneAudioSourceTests` with a capture double);
ExperiencesCreative on sim-27.2 (`ScopeAccuracyAuditTests`, `ScopeQualityTests`, `ScopeAnnouncerTests`, description
tests, session and render tests, manifest); app build and unit; runner iOS 27; public API; package check; contract;
script tests. **Performance**: measured only on devices later; the level arithmetic is tested. **Constraints**: tests
< 10 s; iOS 27 only; reference regression at X-A08; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no new renderer or context) · II PASS (stereo microphone in VisualCore beside the mono one; audit, announcer and
quality in the experience) · II-a PASS (regression at X-A08) · III PASS (route change rebuilds capture; quality level
never touches state) · IV PASS (audit, quality and announcer host-free) · V PASS (no schema change) · VI PASS
(simulator evidence only; device items recorded) · VII PASS (spoken description and paced announcements) · VIII PASS
(the same permission and usage string; no recording) · IX PASS (bounded levels, rate-limited speech) · X–XIII PASS.
A08 rules: truthful (no latency or calibrated claims), bounded resources (levels) — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{StereoMicrophoneAudioSource,StereoMicrophoneCapture}.swift      new
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/StereoMicrophoneAudioSourceTests.swift                      new
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeQuality,ScopeAnnouncer}.swift                            new
Packages/ExperiencesCreative/OscilloscopeStudio/CoreTests/{ScopeQualityTests,ScopeAnnouncerTests}.swift             new
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/{Adapter/ScopeCore,Adapter/ScopeManifest,ScopePresenter,
  ScopeAccuracyAudit}.swift; ExperienceTests/{ScopeAccuracyAuditTests,ScopeDescriptionTests,ScopeSessionTests,
  ScopeManifestTests}.swift; scenario-manifest.json                                                              modify/new
Catalog/registrations.json (a08 quality_tiers), docs/api/visualcore-public-api.txt, Packages/VisualCoreRendering/README.md,
  docs/apps/oscilloscope-studio/{device-campaign.md,visualcore-contract.json}, docs/release/known-limitations.md       modify/new
```

**Dependency direction** unchanged. **Lifecycle**: the stereo microphone source follows the mono source's lifecycle
(stop on suspend, rebuild on route change, resume after interruption); the announcer is owned by the presenter.
**Migration**: none. **Rollback**: revert the commits; the new source is additive.

## Parallel work

Agent A: VisualCoreAudio stereo microphone source + tests. Agent B: core `ScopeQuality`, `ScopeAnnouncer` + tests.
Agent C: accuracy audit + tests (needs neither A nor B). Agent D: presenter wiring, description tests, microphone switch after A and B. Lead: registrations,
manifest fixture, device-campaign document, contract, API baseline, runs, commits.
