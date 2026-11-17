# Implementation Plan: Aurora — Phase 04 Audio and low-power experience

**Branch**: `155-au-p04-loop-lowpower` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-LOOP (a VisualCore change) and G-LOWPOWER (app-local):
- **VisualCore:** `AmbientLoopRecipe`/`AmbientLoopSynth` (VisualCoreAudioDSP) and `AmbientLoopPlayer`
  (VisualCoreAudio), documented, tested, in the API baseline and both package READMEs, with the reference regression.
- **Experience:** the still view over `CachedScene`, the reduced-flash mode (no twinkle, 4.0 s changes, step < 0.02),
  the fallback gradient sky with its message, and render-target bytes back to the baseline after preset changes.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/loop.md](contracts/loop.md), [contracts/lowpower.md](contracts/lowpower.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, AVFoundation (VisualCoreAudio only), GLSL as text. **Dependencies:** none new; the experience
  does not link VisualCoreAudio in this phase.
- **Testing:** `swift test --package-path Packages/VisualCore --filter VisualCoreAudioDSPTests`; VisualCoreRendering's
  `VisualCoreAudioTests` on sim-27.2; `AuroraCoreTests` and `AuroraExperienceTests` on sim-27.2;
  `scripts/check_public_api.py`; the reference regression in two chunks.
- **Constraints:** the ambient session only; no microphone; no permission; each test under 10 s. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II | PASS: the loop is generic and goes into VisualCore; the low-power policy stays in the experience |
| II-a | PASS: the reference regression runs after the VisualCore change |
| X–XIII | PASS: `///` documentation, the API baseline update, the READMEs, tests |
| A21 | PASS: sound off by default and not played yet; nothing flashes; the fallback is calm, never grey |

Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/AmbientLoop.swift                           new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/AmbientLoopSynthTests.swift               new
Packages/VisualCoreRendering/Sources/VisualCoreAudio/AmbientLoopPlayer.swift                new
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/AmbientLoopPlayerTests.swift        new
Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md (module rows)         modify
docs/api/visualcore-public-api.txt                                                          update
Packages/ExperiencesCreative/Aurora/Core/SkyShader.swift (fallback gradient source)         modify
Packages/ExperiencesCreative/Aurora/Experience/{AuroraPresenter,AuroraControls,SkyTransition}.swift   modify
Packages/ExperiencesCreative/Aurora/ExperienceTests/{StillViewTests,ReducedFlashTests,FallbackTests,TargetReleaseTests}.swift new
docs/apps/aurora/visualcore-contract.json (G-LOOP, G-LOWPOWER closed)                       modify
```

- **Dependency direction:** VisualCoreAudio → VisualCoreAudioDSP; the experience → VisualCoreRendering (no audio yet).
- **Lifecycle:** the player's engine starts lazily on `play()` and stops on interruption, media-services reset and
  backgrounding; the still view holds one picture; the fallback replaces the sky scene on a compile failure.
- **Migration:** none (no snapshot or preference change). **Rollback:** revert the commits; the API baseline returns
  with them.

## Parallel work

- **Agent A:** the VisualCore loop (both files, tests, READMEs).
- **Agent L:** the experience's low-power work and tests.
- **Lead:** the API baseline, the reference regression, the contract, runs and commits.
