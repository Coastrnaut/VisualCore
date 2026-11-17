# Data Model: A21-P05 (feature 156)

- **Sound choice** (unchanged from A21-P04): `SkyPreferences.soundOn` (default false) and `volume` ∈ 0…1 (default
  per `SkyPreferences.defaults`), in `prefs.v1`. It is not in the core, the snapshot, the digest or the manifest.
- **SkySound state:** `wanted` (= soundOn), `onScreen` (the controls view appeared and has not disappeared) and
  `active` (scene phase is active, true at start). The loop should play when `wanted && onScreen && active`.
  - When that condition becomes true, `play()` is called; when it becomes false, `stop()` is called.
  - `volume` is passed as a Float on every change.
  - When the player stopped itself (an interruption or the background), nothing restarts it until one of the three
    inputs changes to true again.
- **Cadence:** `FramePacing(thermal: .nominal, lowPower: true, requestedMaxFPS: 60).maxFPS == 30`. The sky time after n
  frames equals the sum of the clamped deltas times the speed. 60 × 1/30 and 120 × 1/60 both reach 2.0 s (±1e-6). As built, the tests
  give each drawn frame its delta through `AuroraPresenter.fixedDelta` (test only, nil in the app).
- **Campaign row:** an id AU-D1…D8, the measurement, the devices, the procedure, the pass condition, and the status
  "pending device campaign".
