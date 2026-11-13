# Research: A04-P06 (feature 038)

## 0. Verified sources (PU = `Packages/ExperiencesCreative/ParticleUniverse`)

- `PU/Experience/ParticleLibrary.swift`: private `File {id, saved, document}`; `reload()` counts `unreadable` and
  `newer` (newer = `SceneError.unsupportedVersion(v)` with `v > SceneDocument.version`).
- `PU/Experience/ParticlePresenter.swift`: `draw(_:tier:context:frame:)` throws; `scene.brightnessCap = reduceFlashing ?
  0.6 : 1`.
- `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceSession.swift`: `hostReported(_:)` →
  `failIfExperienceFailed()` → `fail(_:)` → `.failed`; `retry()`.
- `scripts/check_app_release.py`: `checklist_problems(text)`; statuses `verified`, `pending-campaign-ii`,
  `owner-action`.
- `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy`; `scripts/release_check.py` `unified_app_steps`.
- UI test `PUSandboxUITests.testReduceMotionStartsPaused` runs in the one app (chunk j2) with `-uitestReduceMotion`.

## 1. Decisions (clarifications binding)

- **D1 Failure seam:** `ParticlePresenter.failNextDraw` (internal `var`, false by default) makes the next draw throw
  `ParticleDrawError.injected`. Rationale: proves the real host → session path without a launch argument. Alternative:
  a renderer-failure launch argument (exists only for the standalone `SceneModel`; rejected, ships in Release).
- **D2 Library format:** `format: Int` encoded in `File`; decoding uses `decodeIfPresent ?? 1`; `format > 1` throws a
  private `LibraryFormatError.newer` counted in `newer`. Alternative: a version inside the file name (rejected: rename
  churn).
- **D3 Reduce Motion:** the hosted proof is the existing UI test `testReduceMotionStartsPaused` (j2 chunk, one app);
  the pause is sent by `ParticleControls`' `.task`, which a package test cannot run. Reduce Flashing gets a package
  test through the session (`ParticlePresenter.brightnessCap`).
- **D4 Release document check:** `scripts/check_experience_release.py --config docs/apps/particle-universe/release.json`
  imports `checklist_problems` from `check_app_release.py`; config schema 1: `experience`, `requiredDocs`, `checklist`.
- **D5 Copy check:** `scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --text <md> --swift
  <files>`; Swift string literals are extracted with a regex for `"…"`; matches are case-insensitive word or pattern
  hits; exit 1 with each hit `file:line: term`.
- **D6 Build and archive:** `docs/release/build-and-archive.md` lists `verify_environment.py`, `xcodegen generate`,
  `release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses
  app-usage-descriptions`, and owner steps (team, signing, Product › Archive, upload, App Store Connect).
