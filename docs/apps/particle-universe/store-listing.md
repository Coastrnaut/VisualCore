# Particle Universe — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Particle Universe is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Its
catalog entry is still marked `available: false` until the X-A04 gate integrates it.

Every sentence below describes a control that exists in `ParticleUniverse/Experience/ParticleControls.swift` and is
exercised by the interface tests named in the traceability table. The text is checked by
`scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`.

## Text

**Particle Universe** — a particle sandbox inside VisualCore, free to use.

Build a moving field of glowing particles with your fingers. Choose an emitter family (Fountain, Curtain, Halo or
Firework), add more emitters and move them, and set particle size, lifetime and colour gradient for each one.

Tap the canvas to place a force and drag it to move it: an attractor, a repulsor, a gravity well, wind or a vortex,
with adjustable strength. Turn on trails and set their strength, or switch to a glowing blend.

Pause the scene, step it forward while paused, or start again with a new seed. Save the scenes you like under a
name, then open, rename or delete them later; they stay on your device.

With Reduce Motion the scene starts paused, and with Reduce Flashing its brightness is capped. VoiceOver describes
the scene on the canvas.

## Traceability

| Claim | Proof |
|---|---|
| Emitter families Fountain, Curtain, Halo, Firework | `PUSandboxUITests.testEveryFamilyIsSelectableAndDescribed` (chunk j2) |
| Add, select, remove and move emitters; size, lifetime, colour gradient | `PUEmitterUITests` (chunk j3); moving: `ParticleEditorTests` (package), `PUSceneLibraryUITests` (chunk j4) |
| Place a force by tapping, move it by dragging; attractor, repulsor, gravity well, wind, vortex; strength | `PUForceUITests` (chunk j3) |
| Trails, trail strength, glowing blend | `PUTrailUITests.testTrailsStrengthAndBlend` (chunk j3) |
| Pause, step, new seed | `PUSandboxUITests.testPauseStepAndNewSeed` (chunk j2) |
| Saved scenes: save, open, rename, delete; stored on the device | `PUSceneLibraryUITests` (chunk j4); [privacy-and-credits.md](privacy-and-credits.md) |
| Reduce Motion starts paused | `PUSandboxUITests.testReduceMotionStartsPaused` (chunk j2) |
| Reduce Flashing caps brightness | `ParticleRecoveryTests` (package); `PUTrailUITests.testTrailsWorkUnderReduceFlashing` (chunk j3) |
| VoiceOver describes the scene | `PUSandboxUITests.testOpenFromTheCatalogShowsTheDescribedCanvas` (chunk j2) |
| Free tier | `Catalog/experiences.json` (`a04.particle-universe`, `tier: free`) |

No speed, timing or device claim is made; those wait for the device campaign ([device-campaign.md](device-campaign.md)).
