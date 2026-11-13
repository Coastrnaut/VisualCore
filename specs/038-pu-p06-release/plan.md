# Implementation Plan: Particle Universe — Phase 06 Final verification, privacy, packaging and release

**Branch**: `038-pu-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Close Particle Universe's release readiness inside the one app: version the library file wrapper and prove every file
form with committed fixtures; prove that a drawing failure reaches the session's failure state and retry, and that
Reduce Flashing caps brightness in the hosted path; add an experience-level release document check and a copy-claim
check; write the experience's release documents and the one app's build-and-archive instructions. Research:
[research.md](research.md). Audit: `Build/agent-notes/A04-P06-audit.md`.

## Technical Context

**Language**: Swift 6, Python 3 (scripts). **Dependencies**: existing packages; no VisualCore change. **Storage**:
`ParticleLibrary` files in the experience's `ExperienceStorage` (format field added). **Testing**: ExperiencesCreative
package on sim-27.2 and sim-26.5; PU interface chunks j2–j4 on the iOS 27.2 phone; `scripts/test_scripts.py`.
**Performance**: unit tests < 10 s each. **Constraints**: no new permission, network or launch argument; test seams are
internal (`@testable`) and absent from the public API; device work is {device}; owner steps are `BLOCKED_OWNER_ACTION`.

## Constitution Check

I one renderer PASS · II/II-a no VisualCore change PASS · III main-actor presenter, value-type library file PASS ·
IV test-first (fixtures and failing checks first) PASS · V devices only after ImplementationLock-100 ({device} task)
PASS · VI evidence: simulator results labelled, nothing measured is claimed PASS · VII accessibility unchanged, audits
deferred by owner ruling PASS · VIII privacy: no collection, manifest covers the APIs PASS · IX money: no purchase or
advertising touched PASS · X–XIII PASS. Post-design re-check: PASS (no new dependency direction).

## Project Structure

```text
PU = Packages/ExperiencesCreative/ParticleUniverse
PU/Experience/ParticleLibrary.swift                      modify  `format` field (absent = 1), newer format counted
PU/Experience/ParticlePresenter.swift                    modify  internal `failNextDraw` seam; `brightnessCap` read
PU/ExperienceTests/Fixtures/Library/*.json               new     no-format, format-1, format-2, damaged
PU/ExperienceTests/ParticleLibraryMigrationTests.swift   new     the four fixtures, rewrite on rename keeps format 1
PU/ExperienceTests/ParticleRecoveryTests.swift           new     drawing failure → failed, saved scenes unchanged,
                                                                 retry → running; Reduce Flashing cap in the session
Packages/ExperiencesCreative/Package.swift               modify  ExperienceTests resources: Fixtures
scripts/check_experience_release.py                      new     required docs + checklist (reuses check_app_release)
scripts/check_copy_claims.py                             new     denylist scan of store text and interface strings
Configs/copy-claims-denylist.json                        new     versioned denylist (schema 1)
scripts/test_scripts.py                                  modify  tests of the two scripts (pass and fail cases)
scripts/release_check.py                                 modify  steps experience-release-a04, copy-claims-a04
docs/apps/particle-universe/release.json                 new     required documents and checklist path
docs/apps/particle-universe/release-checklist.md         new     artifact inventory with Status and Evidence
docs/apps/particle-universe/privacy-and-credits.md       new
docs/apps/particle-universe/store-listing.md             new     store text input (owner enters it)
docs/apps/particle-universe/device-campaign.md           new     pending device measurements and audits
docs/apps/particle-universe/README.md                    modify  links to the release documents
docs/release/build-and-archive.md                        new     the one app: unsigned commands, owner steps
docs/release/known-limitations.md                        modify  Particle Universe device-only items
```

**Dependency direction**: Core ← Experience (library, presenter) ← app registry; scripts read documents only.
**Lifecycle**: the failure seam throws from `ParticlePresenter.draw`; `ExperienceSession.hostReported` →
`failIfExperienceFailed` → `fail` → `.failed`; `retry()` opens a new experience (seam cleared with the old presenter).
**Migration**: files without `format` read as 1; every save and rename writes `format: 1`; files with `format > 1` are
counted as newer and never rewritten. **Rollback**: revert the commits; files written with `format: 1` stay readable by
the previous reader only if it ignores unknown keys (it does: `JSONDecoder` ignores extra keys) — verified by a test.

## Parallel work

Agent A: library format + fixtures + migration tests (ParticleLibrary.swift, Fixtures, ParticleLibraryMigrationTests).
Agent B: recovery tests + presenter seam (ParticlePresenter.swift, ParticleRecoveryTests). Agent C: the two scripts and
the denylist (handed over as separate files; the lead adds their tests to test_scripts.py and the release_check steps).
Agent D: the release documents and build-and-archive. Lead: Package.swift, test_scripts.py, release_check.py,
known-limitations.md, runs, ticks and commits.
