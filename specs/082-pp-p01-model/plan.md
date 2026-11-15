# Implementation Plan: Physics Playground — Phase 01 Physics model, units and deterministic tests

**Branch**: `082-pp-p01-model` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close the contact part of G-CONTACTS upstream in `VisualCoreSimulation` (`Shape2D`, `Pose2D`, `ContactManifold2D`,
`Contacts2D.collide` for circle–circle, circle–box and box–box, `RigidBodyState2D`, `Contact2D`, `ImpulseSolver2D` with
restitution, friction and positional correction; pure, deterministic, host-tested), and G-RIGIDBODY and
G-CONTENTLICENSES in the new experience `a11.physics-playground` in `Packages/ExperiencesCreative/PhysicsPlayground`:
Core (`MaterialCatalog` with licensed materials and a validating decoder, `LicenseAudit`, `PhysicsWorld` schema 1 with
`WorldSettings` and `PhysicsBody`, `StartingScene`, `WorldSimulation` — gravity, drag, semi-implicit integration, speed
caps, all-pairs and wall contacts through the solver, pause, single step, time scale, drop, reset — and
`WorldDiagnostics`), Experience (adapter `PlaygroundCore`, manifest, presenter drawing the stage, walls and bodies
through `PrimitiveRenderer`, native controls), registered as a candidate with nine standard scenarios and ten
fixtures. Generated `docs/apps/physics-playground/content-licenses.md`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreMath` (`Vec2`: `+ - *`, `dot`, `cross`, `length`, `normalized`,
`isFinite`; `Camera2D`), `VisualCoreSimulation` (`SeededRandom` and its saved state; the new contact and solver API),
`VisualCoreScenes` (`SceneNode`, `Primitive.circle/.polygon/.rect/.line`), `VisualCoreRendering` (`PrimitiveRenderer`),
`VisualCoreExperience` (`ExperienceCore`, `ExperienceAction` with `step`, `MigrationChain`), `VisualCoreExperienceHost`,
`VisualCoreUI`. **Storage**: experience snapshot (`PlaygroundState` schema 1); no files written. **Testing**: host
`swift test --package-path Packages/VisualCore --filter "Contacts2DTests|ImpulseSolver2DTests"`; ExperiencesCreative on
sim-27.2 (`PhysicsPlaygroundCoreTests`, `PhysicsPlaygroundExperienceTests`); public API check; app build and unit;
runner iOS 27; experience package check; contract; script tests. **Performance**: ≤ 48 bodies + 4 walls, ≤ 1,326
pair tests and 10 solver iterations per tick; ≤ 60 shapes per frame; 10,000-tick runs measured on a few seeds and
bounded by arithmetic (no wall-clock assert on CI). **Constraints**: tests < 10 s; iOS 27 only; reference regression
and iOS 26 at X-A11 (owner ruling 2026-11-14); no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `PrimitiveRenderer`; no context) · II PASS (generic contacts and the impulse solver in
VisualCore; world, materials, scene and diagnostics in the experience) · II-a PASS (VisualCore change documented, API
baseline updated; seven-step reference regression at X-A11) · III PASS (the world advances only by host steps;
suspension stops it) · IV PASS (contacts and solver host-tested; world, catalog, audit and simulation tested without
GPU) · V PASS (snapshot schema 1 with migration chain) · VI PASS (render tests on the simulator) · VII PASS (native
controls for every action; spoken state; no decorative motion) · VIII PASS (no permission, no network) · IX PASS
(bodies ≤ 48, speeds capped, iterations fixed) · X PASS (all materials original, MIT, recorded) · XI–XIII PASS. A11
rules (2.7.0): authoritative GPU-free physics, stable and bounded, visuals as code, offline, truthful (diagnostics are
educational approximations), licenses — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/{Contacts2D,ImpulseSolver2D}.swift                       new
Packages/VisualCore/Tests/VisualCoreSimulationTests/{Contacts2DTests,ImpulseSolver2DTests}.swift          new
Packages/VisualCore/README.md (rigid-body section), API baseline (check_public_api.py --update)          modify
Packages/ExperiencesCreative/PhysicsPlayground/Core/{MaterialCatalog,LicenseAudit,PhysicsWorld,StartingScene,
  WorldSimulation,WorldDiagnostics}.swift                                                                  new domain
Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{MaterialCatalogTests,LicenseAuditTests,PhysicsWorldTests,
  WorldSimulationTests,PhysicsFixtureTests,ReplayTests}.swift                                              new
Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore.swift,
  Adapter/PlaygroundManifest.swift,PlaygroundPresenter.swift,PlaygroundControls.swift,
  PhysicsPlaygroundExperience.swift}                                                                       new
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/{PlaygroundCoreTests,PlaygroundManifestTests,
  PlaygroundSessionTests,PlaygroundRenderTests,PlaygroundTestSupport}.swift; PhysicsPlayground/scenario-manifest.json new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate id moves past a11)                                                    modify
docs/apps/physics-playground/{content-licenses.md (generated), visualcore-contract.json (G-RIGIDBODY,
  G-CONTENTLICENSES and the contact part of G-CONTACTS closed by A11-P01; G-BROADPHASE added for A11-P02), README}
                                                                                                           new/modify
```

**Dependency direction** (targets `PhysicsPlaygroundCore`, `PhysicsPlaygroundExperience`, their test targets and the
product `PhysicsPlaygroundExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is
`PlaygroundCore` so it does not shadow the module): PhysicsPlaygroundExperience → PhysicsPlaygroundCore →
VisualCoreSimulation, VisualCoreMath; the experience → scenes, rendering, host, UI; nothing in VisualCore depends on the
experience.

**Lifecycle**: the core holds the `PhysicsWorld` and the generator; `update(step:)` runs the whole ticks the time scale
allows unless paused; actions apply at their step, so the applied actions with the seed are the replay; the host steps
only while running, so suspension never catches up. The presenter owns one `PrimitiveRenderer` created when the host's
context is current and released in teardown; it rebuilds the node tree from the world each frame and never writes to
it. **Migration**: none (new schema 1). **Rollback**: revert the commits (the VisualCore files are additive).

## Parallel work

Agent A: `Contacts2D.swift`, `ImpulseSolver2D.swift` and their tests (contracts/api.md). Agent B: PhysicsPlayground Core
and CoreTests (uses the contact API by its contract). Agent C: Experience target and tests after A and B land. Lead:
README, API baseline, Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, license
document, contract, runs, commits.
