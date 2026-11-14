# Implementation Plan: Oscilloscope Studio — Phase 06 Final verification, privacy, packaging and release

**Branch**: `066-os-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness for a08 following A07-P06: privacy and credits note, store-text input with traceability, release
checklist with artifact inventory, the device-campaign plan (started in A08-P05) completed with CPU/GPU, memory,
persistence and accessibility rows, and `release.json` (copy allow list audio/microphone) under
`docs/apps/oscilloscope-studio/`; signal-unit markers on the five copy-check lines; a no-network/no-recording scan; five
committed preset fixtures and a migration test; a recovery test through the existing `failNextDraw` seam; interface
chunk "p2" (`OSScopeUITests`, `OSPresetsUITests`); the release build checks; owner-only and device items recorded
open. No VisualCore change. Research: [research.md](research.md); model: [data-model.md](data-model.md); contract:
[contracts/release-config.md](contracts/release-config.md); evidence: [quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6, Python 3 (existing scripts), Markdown/JSON documents. **Verified tooling**:
`scripts/check_experience_release.py --config docs/apps/<slug>/release.json`, `scripts/check_copy_claims.py` with
`--allow` and the `copy-claims: allow` line marker, `scripts/release_check.py` steps `experience-release-a08`,
`copy-claims-a08`, `app-ui-ios27-<chunk>` from `UI_CHUNKS`, `app-release-*` release checks; `ScopePresetStore`
(`reload()`, `unreadable`, `newer`), `ScopePreset`, `ExperienceStorage`, `ScopePresenter.failNextDraw` /
`ScopeDrawError.injected`, the session failure path of A07 (`OdysseyRecoveryDrawTests`). **Storage**: none new.
**Testing**: experiences package on sim-27.2 (fixtures, recovery), app build/unit/interface chunk p2, runner iOS 27,
release build checks, script tests. **Constraints**: interface tests < 60 s, package tests < 10 s; iOS 27 only;
reference regression at X-A08. No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no rendering change) · II PASS (no VisualCore change) · III PASS (failure path through the host; reopen draws) ·
IV PASS (fixtures simulator-tested) · V PASS (every preset form tested; refused files kept) · VI PASS (interface chunk;
device rows pending) · VII PASS (identifiers exercised; audits in the device campaign) · VIII PASS (one disclosed
permission; privacy note; no network) · IX PASS (no fabricated measurement or latency) · X PASS (credits: no
third-party assets) · XI–XIII PASS · A08 PASS (relative to full scale; no calibrated, certified, laboratory or medical
claim; no recording). Post-design: PASS.

## Project Structure

```text
docs/apps/oscilloscope-studio/{privacy-and-credits.md,store-listing.md,release-checklist.md,release.json}          new
docs/apps/oscilloscope-studio/device-campaign.md (CPU/GPU, memory, persistence, Dynamic Type, Reduce Motion rows)   modify
docs/release/known-limitations.md (A08 rows: quota, restored file, device items)                                      modify
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/ScopePresenter.swift (5 lines: copy-claims allow marker)   modify
scripts/release_check.py (UI_CHUNKS "p2")                                                                             modify
Packages/ExperiencesCreative/Package.swift (resources: [.copy("Fixtures")] on OscilloscopeStudioExperienceTests)       modify
Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/Fixtures/scope-00000000-0000-4000-8000-0000000008c{1..4}.json
  and scope-00000000-0000-4000-8000-0000000008A1.json (claims a built-in id)                                          new
Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/{ScopePresetMigrationTests,ScopeRecoveryDrawTests}.swift new
Apps/VisualCore/Tests/UI/OscilloscopeStudio/{OSSupport,OSScopeUITests,OSPresetsUITests}.swift                         new
project.yml (VisualCoreUITests sources glob Apps/VisualCore/Tests/UI)                                                  check
```

**Dependency direction**: unchanged. **Lifecycle**: `failNextDraw` clears itself after one throw. **Migration**: none
(fixtures exercise existing formats). **Rollback**: revert; documents only otherwise.

## Parallel work

Agent A: documents + release.json + known-limitations + device-campaign rows. Agent B: fixtures + migration test +
recovery test + Package.swift resources. Agent C: interface chunk files. Lead: copy markers, release_check chunk, runs,
commits.
