# Implementation Plan: VisualCore Music Lab — Phase 06 Final verification, privacy, packaging and release

**Branch**: `052-ml-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness for a06 following A05-P06: privacy and credits note, store-text input with traceability, release
checklist with artifact inventory, device-campaign plan and `release.json` (copy allow list audio/music/microphone) under
`docs/apps/visualcore-music-lab/`; a no-network/no-recording scan; five committed preset fixtures and a migration test;
an internal `failNextDraw` seam with a recovery test; interface chunk "m2" (`MLScenesUITests`, `MLPresetsUITests`); the
release build checks; owner-only and device items recorded open. No VisualCore change. Research: [research.md](research.md);
model: [data-model.md](data-model.md); contract: [contracts/release-config.md](contracts/release-config.md); evidence:
[quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6, Python 3 (existing scripts), Markdown/JSON documents. **Verified tooling**:
`scripts/check_experience_release.py --config docs/apps/<slug>/release.json`, `scripts/check_copy_claims.py` with
`--allow`, `scripts/release_check.py` steps `experience-release-a06`, `copy-claims-a06`, `app-ui-ios27-<chunk>` from
`UI_CHUNKS`, `app-release-*` release checks, `MusicLabPresetStore`, `MusicPreset.decode`, `ExperienceStorage`,
`ExperienceSession`/`failedReason` pattern of A05. **Storage**: none new. **Testing**: experiences package on sim-27.2
(fixtures, recovery), app build/unit/interface chunk m2, runner iOS 27, release build checks, script tests.
**Constraints**: interface tests < 60 s, package tests < 10 s; iOS 27 only; reference regression at X-A06.

## Constitution Check

I PASS (no rendering change) · II PASS (no VisualCore change) · III PASS (failure path through the host; reopen draws) ·
IV PASS (fixtures host/simulator-tested) · V PASS (every preset format tested; refused files kept) · VI PASS (interface
chunk) · VII PASS (accessibility identifiers exercised; audits in the device campaign) · VIII PASS (one disclosed
permission; privacy note; no network) · IX PASS (no fabricated measurement; device items pending) · X PASS (credits: no
third-party assets) · XI–XIII PASS · A06 PASS (no recording, no health claims).

## Project Structure

```text
docs/apps/visualcore-music-lab/{privacy-and-credits.md,store-listing.md,release-checklist.md,device-campaign.md,release.json}  new
docs/release/known-limitations.md (Music Lab device-only items)                                                                 modify
scripts/release_check.py (UI_CHUNKS "m2")                                                                                      modify
Packages/ExperiencesCreative/Package.swift (resources: [.copy("Fixtures")] on VisualCoreMusicLabExperienceTests)              modify
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/Fixtures/preset-00000000-0000-4000-8000-0000000006b{1..5}.json  new (b5 named with a built-in id: preset-…6a1)
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/{MusicLabPresetMigrationTests,MusicLabRecoveryDrawTests}.swift   new
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/MusicLabPresenter.swift (failNextDraw, MusicLabDrawError)           modify
Apps/VisualCore/Tests/UI/MusicLab/{MLSupport,MLScenesUITests,MLPresetsUITests}.swift                                            new
project.yml (UI test sources include the new folder if not globbed)                                                             check
```

**Dependency direction**: unchanged. **Lifecycle**: `failNextDraw` clears itself after one throw. **Migration**: none
(fixtures exercise existing formats). **Rollback**: revert; documents only otherwise.

## Parallel work

Agent A: the five documents + release.json + known-limitations row. Agent B: fixtures + migration test + Package.swift
resources. Agent C: interface chunk files. Lead: failure seam + recovery test, release_check chunk, runs, commits.
