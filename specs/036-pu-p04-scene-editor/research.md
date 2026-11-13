# Research: Particle Universe Phase 04 — Scene editor and persistence

**Date**: 2026-11-13 · **Spec**: [spec.md](spec.md)

## 0. Read-only audit (`main` at `6067fc90`; `Build/agent-notes/A04-P04-audit.md` re-verified). PU = `Packages/ExperiencesCreative/ParticleUniverse`.

| Source | Verified |
|---|---|
| `PU/Core/ParticleScene.swift` | `ParticleScene` (emitters 1…`maxEmitters` 8, forces 0…`maxForces` 8, `limitRange` 100…20,000, `timeScaleRange` 0.25…2), `SceneEmitter` (family, position `Vec2?`, size `1…48`, lifetime `0.2…8`, gradient `String?`), `SceneForce` (7 kinds), `SceneError` (unsupportedVersion, nonFinite, limitOutOfRange, timeScaleOutOfRange, emitterCount, forceCount, invalidForce, invalidEmitter); version 1 validated on decode |
| `PU/Core/PlacedForce.swift` | `PlacedForce`, `PlacedForceKind`, `worldHalfExtent = 500` (scene bounds ±500), `strengthRange`; not Codable |
| `PU/Core/SceneSimulation.swift` | `setEmitter(at:_:)` (replace family, position, overrides), `placement(of:index:)`, `rebuildScene(seed:)` |
| `PU/Experience/Adapter/ParticleCore.swift` | `ExperienceCore`; `Anchor` (scene, playing, selectedEmitter, selectedKind, force `[Double]?`, strength, trailsOn, trailStrength, additive); controls list (lines ~109-127: family, emitter.add/remove/select, size, lifetime, gradient, trails, trailStrength, blend, force.kind/place/nudge/center, strength, play, pause, step, reseed); `force.place` maps 0…1 to ±`worldHalfExtent`; `gradientIDs`; `writeDigest(into:)`; snapshot `migrations` at v1 |
| `PU/Experience/ParticleExperience.swift` | `make(id:reduceMotion:reduceFlashing:)` — no storage yet |
| `Apps/VisualCore/App/ExperienceRegistry.swift:118-128` | `particleUniverse` registration (candidate list) calling `ParticleExperience.make` |
| `Packages/ExperiencesCreative/FractalExplorer/Experience/FractalBookmarks.swift`, `FractalExperience.make(id:storage:reduceMotion:)`, registry `launch.storage` | pattern for a named library over `ExperienceStorage` |
| `Packages/VisualCore/Sources/VisualCoreExperience/ExperienceStorage.swift` | `write(_:to:)`, `read(_:)`, `exists`, `list()`, `remove(_:)`; `maxFiles` 64, `maxBytes` 16 MiB, `maxNameLength` 128; typed `StorageError` |
| `ExperienceControl.maxValues` | 8 values per action |
| `Apps/VisualCore/Tests/UI/ParticleUniverse/` | `PUSupport.swift`, `PUSandboxUITests`, `PUEmitterUITests`, `PUForceUITests`, `PUTrailUITests` (chunks j2/j3 of the release check) |
| `PU/CoreTests/Fixtures/replay-v1.json`, `PU/scenario-manifest.json`, `ParticleManifest.swift` digests | must keep decoding / be regenerated only for changed scenarios |

## 1. Decisions (clarifications binding)

- **D1 SceneDocument** (Core, pure): `struct SceneDocument: Codable, Equatable, Sendable { version: Int (2), scene: ParticleScene, force: SavedForce?, trailsOn: Bool, trailStrength: Double, additive: Bool }`, `SavedForce { kind: String, x, y, strength }`; `decode(_:) throws(SceneError)` accepts version 1 (a bare `ParticleScene`) by migration and version 2; refuses newer; validates finite values and ranges.
- **D2 Open sequence** (Core): `SceneDocument.openActions() -> [ScriptedAction-like (id, values)]` producing `scene.begin`, `emitter.define`×n, `force.define`, `look.define`; `ParticleCore` handles them: `scene.begin` starts a pending open; defines fill it; `look.define` commits atomically (validated with `ParticleScene` rules) or rejects and discards. Positions travel as scene coordinates within ±`worldHalfExtent`.
- **D3 emitter.move** (Core/adapter): absolute scene point (x, y) clamped to ±`worldHalfExtent`, applied with `SceneSimulation.setEmitter(at:_:)` keeping family and overrides; direction buttons step 50 points.
- **D4 ParticleLibrary** (Experience): the `FractalBookmarks` pattern: files `scene-<uuid>.json` in `ExperienceStorage`, entries (id, name, saved), `save(_:name:)` with numbered suffix on clash, `rename` refusing clashes, `remove`, `problems` (unreadable files counted, never deleted), writes through `ExperienceStorage.write` (atomic replace).
- **D5 Wiring**: `ParticleExperience.make(id:storage:reduceMotion:reduceFlashing:)`; registry passes `launch.storage`; `ParticleControls` gains a Library section (save field, list with open, rename, delete) and Move buttons.
- **D6 Snapshot**: `Anchor` gains no fields (the opened scene is the anchor's scene after commit); new actions are logged, so `migrations` stay at v1 and `replay-v1.json` still decodes.
- **D7** No VisualCore change.

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

Round 1: 0 critical, 0 high, 1 medium (C1: storage-limit save failure test added to T-A04-406), 1 low (C2: no-VisualCore-
change check added to T-A04-417). Round 2: clean; 22 of 22 requirements and 6 of 6 success criteria covered.

## 3. Implementation notes (T-A04-403, 2026-11-13)

- `SceneError.invalidDocument(String)` added (damaged JSON, name, force and look ranges); no exhaustive switches exist.
- Opening reproduces the FR-A04-402 fields (emitters, placed force, trails, trail strength, blend). The scene's seed,
  particle limit, time scale and scene-level forces are not editable in this slice and stay as they are when a scene is
  opened; the saved document still records them.
- An emitter saved with an explicit position equal to its family default reopens with no explicit position (same
  behaviour); tests compare positions through `SceneSimulation.placement`.
- Defaults: trails off, trail strength 0.85, blend not additive (`SceneDocument.default*`), shared with `ParticleCore`.
- The default scene has one emitter; the interface test compares the emitter count against the saved one instead of a
  fixed number. Typing ends with a return so the keyboard does not cover the save button.
- SC-A04-406 corrected: unit tests stay under 10 s (the new ones run in under 1 s); the interface test bound is 3 minutes
  (the first passing run took 169 s; existing PU interface tests take 40–90 s each).
- Opening rejects an invalid define by leaving the open incomplete (the engine restores the core after a rejected
  action), so the following `look.define` is refused for the wrong count and the scene stays unchanged; a new
  `scene.begin` discards it.
