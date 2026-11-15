# Neon Arcade (`a10.neon-arcade`)

A compact arcade game with glow, particles and disciplined game logic (archived manual `apps/10-neon-arcade.md`
§1–§2). Version 0.1 is one complete game, **Neon Dodge**: a player lane, falling hazards and collectible orbs, played
at a deterministic fixed step from a seed; authoritative collision between the player, hazards and orbs;
start/pause/restart/game-over flows with local scores; touch steering with configurable sensitivity; glow and particle
feedback constrained by readability; sound and haptic toggles with reduced-flash controls. Non-goals: a whole arcade
collection, online leaderboards, user-generated levels, loot boxes or purchasable currency.

Neon Arcade is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/NeonArcade`; it never has a standalone target. The player, hazards, orbs, glow and
backgrounds are drawn in code and any sound is synthesized in code (no artwork, no recordings). It reuses VisualCore's
seeded fixed-step clock and runner, particles, batched 2D shapes with hit testing, gestures, bloom, haptic and
announcement planning, storage and quality tiers; 2D collision with swept tests and synthesized sound-effect playback
are built in VisualCore (gaps of the contract), the rest in the experience. Its rules are the A10 subsection of the
constitution (2.6.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
| [content-licenses.md](content-licenses.md) | Author and license of the player, every hazard and every orb (generated) |
| [device-campaign.md](device-campaign.md) | Device measurements planned for after `ImplementationLock-100` (frame pacing per quality level, thermal state, glow readability in bright light, audio routes, VoiceOver, high-score survival); nothing measured yet |
| [privacy-and-credits.md](privacy-and-credits.md) | What is stored (`high-scores.json`, the session state) and where, how to delete it, permissions (none), sound and haptics, what is not done, required-reason APIs, credits |
| [store-listing.md](store-listing.md) | Store text input for the one app's listing, with a claim → proving-test table |
| [release-checklist.md](release-checklist.md) | Release checklist (Item, Area, Status, Evidence) and artifact inventory |
| [release.json](release.json) | Release configuration read by `scripts/check_experience_release.py` and `scripts/release_check.py` (`experience-release-a10`, `copy-claims-a10`) |

Phases: A10-P00 boundary audit (feature 074), P01 fixed-step engine and collision fixtures, P02 Neon Dodge mechanics,
P03 visual effects and audio/haptics, P04 scores and accessibility, P05 balance and device QA preparation, P06
release readiness; then the experience's integration gate X-A10.

## Capabilities and their proof

The catalog entry (`Catalog/registrations.json`, `a10.neon-arcade`) reads "Neon Dodge: steer through falling hazards
and collect orbs in waves." and lists only the capabilities below, each proved by the named tests (feature 079,
A10-P05, FR-A10-521). Simulator and host results; nothing here is a device measurement. `specs/079-na-p05-balance/scan-claims.sh`
checks that every named test exists and that the entry and this page make no benefit claims.

| Capability | Proving tests |
|---|---|
| fixed-step game | `GameSimulationTests.swift` `theStepIsOneSixtiethOfASecond`; `ReplayTests.swift` `replayingTheSameInputsTwiceGivesTheSameRun`; `ArcadeCoreTests.swift` `testTheSameSeedAndRecordedInputsGiveTheSameRun` |
| swept collision | `Collision2DTests.swift` `earliestFractionForAHeadOnCrossing`; `GameSimulationTests.swift` `aFastCircleCrossingThePlayerInOneStepIsCaught`; `GameSimulationTests.swift` `capsulesHitByEndOfStepOverlap` |
| wave patterns | `WaveDirectorTests.swift` `wavesAdvanceEvery600StepsWithAnotherPattern`; `WaveDirectorTests.swift` `everySpawnStartsAtALaneCentreAndThreePatternsAppearPerSeed`; `WaveDirectorTests.swift` `everyWallLeavesExactlyOneFreeLaneNeverThePrevious` |
| local high scores | `HighScoreTableTests.swift` `entriesAreRankedHighestFirst`; `HighScoreStoreTests.swift` `testATableRoundTripsThroughStorageAndARunIsEnteredOnce`; `HighScoreStoreTests.swift` `testAnInterruptedSaveLeavesTheLastCompleteTable` |
| synthesized sounds and haptics | `ArcadeEffectsTests.swift` `theFourSoundShapes`; `ArcadeEffectsTests.swift` `theSoundShapesStayInsideTheLimits`; `ArcadeSessionTests.swift` `testTheSoundAndHapticSinksReceiveCuesOnlyWhenEnabled` |
| five steering sensitivities | `SensitivityTests.swift` `theFiveReachesAndTheDefault`; `SensitivityTests.swift` `oneOffsetIsOrderedGentleToSharpAndBounded`; `ArcadeSessionTests.swift` `testTheDragReachFollowsTheSensitivityStep` |
| three quality levels | `ArcadeBudgetTests.swift` `ArcadeBudgetTests` (the per-level glow, opacity and particle caps) |
