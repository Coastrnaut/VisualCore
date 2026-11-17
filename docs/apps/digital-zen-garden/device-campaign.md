# Digital Zen Garden — device campaign plan (A20-P05, feature 149)

These measurements need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no latency, frame, heat,
battery, precision or accessibility number is claimed anywhere. Simulator results never stand in for these rows: the
simulator gives no touch latency, no thermal state and no battery. Every row is a {device} task (FR-A20-505,
FR-A20-506) and closes the device part of gap G-DEVICE in [visualcore-contract.json](visualcore-contract.json).

Digital Zen Garden rakes a height field on the CPU: the core's reference field of the small tray is 160 × 120
(`SandField`), and the experience draws a 480 × 360 field (`SandScene`), uploaded only when it changed. A drag is
resampled to points every 0.004 tray widths and a stroke ends at the cap of 512 points (`StrokeResampler`). The
presenter draws at most 30 frames per second (`maxFramesPerSecond`), and a still garden is drawn once and the cached
picture is repeated (`CachedScene`). The calm switches `calm.sound`, `calm.drift` and `calm.haptics` are off by
default and kept under `calm.v1`; Reduce Motion forces the drift off at draw time. Sound plays through
`SoundEffectPlayer` in the ambient audio session category, which mixes with other audio and follows the silent
switch; haptics go through the shared haptic route (`ExperienceFeedback`) and only when the person's switch allows
them. The devices are D1 iPhone 15 (iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5.

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, the
silent switch and system haptics setting, and turning Reduce Motion and the text size on and off in Settings are done
by the owner. Each such step is recorded as `BLOCKED_OWNER_ACTION` with its exact steps when the campaign reaches it,
and the other rows continue.

| Row | Measurement | Device | Procedure | Threshold | Status |
|---|---|---|---|---|---|
| ZG-D1 | Touch-to-groove latency | D1 reference iPhone (iOS 27), D2, D3 | Open Digital Zen Garden with the rake tool and drag one finger slowly, then quickly, across the tray. Record the screen and the finger together with a high-frame-rate camera (owner action), and in Instruments (Animation Hitches) record the frames during the drags. Count the camera frames from the finger's movement to the groove under it. | the groove appears under the finger within two frame intervals at the 30 per second cap; no hitch is recorded during the drags | pending device campaign |
| ZG-D2 | Coalesced touches and fast drags | D1, D2, D3 | The presenter reads one touch point per event and `StrokeResampler` fills gaps at 0.004 tray widths. Rake the fastest straight and circular drags the owner can make, ten of each, and photograph the grooves. | every groove is continuous, with no visible chords or corners on a circle; if chords appear, the row records that fast drags need coalesced touches and that becomes a follow-up task, not a pass | pending device campaign |
| ZG-D3 | Idle drawing | D1, D2, D3 | With the quiet defaults (all three calm switches off), rake one pattern, then leave the garden untouched for 2 minutes; record Instruments (Metal System Trace and Animation Hitches). Repeat with `calm.drift` on, and once more with `calm.drift` on and Reduce Motion on (owner action). | quiet defaults, and drift on with Reduce Motion on: the sand pass is not run between inputs and only the cached picture is shown; drift on with Reduce Motion off: frames at no more than the 30 per second cap, with only the grain moving | pending device campaign |
| ZG-D4 | Heat during ten minutes of raking | D1, D2, D3 | Rake continuously for ten minutes with the quiet defaults, starting a new stroke whenever one reaches its cap. Record `ProcessInfo.thermalState` every 5 s (Instruments, thermal state) from the first stroke to one minute after the last. | thermal state never reaches `.critical`; no crash and no dropped stroke; any time at `.serious` is recorded | pending device campaign |
| ZG-D5 | Battery during a long session | D1, D2, D3 | On battery from a full charge, keep the garden open for 30 minutes: rake for one minute in every five, untouched between, with the quiet defaults. Log the battery level every 5 minutes; repeat with `calm.drift` on. | battery use is recorded for both runs, and no claim is made from it; the garden is still open and drawn correctly at the end | pending device campaign |
| ZG-D6 | Precision on the smallest phone (manual risk 2) | D1 (the smallest screen of the campaign), D2 for comparison | Rake the rows pattern with the fine rake, place a stone exactly between two grooves, select the topmost of two overlapping stones, and turn one stone by a small angle; repeat each five times. | every task succeeds at least four times in five on D1 without a brush zoom; otherwise the row records that a brush zoom is needed, with its owner, its verification and its release-blocking condition in `docs/decisions/` (manual risk 2) | pending device campaign |
| ZG-D7 | Quiet defaults and the silent switch | D1, D2, D3 | On a fresh install, open the garden, rake, place and remove a stone: confirm no sound, no drift and no haptic. Turn `calm.sound` on with the silent switch on, then off (owner action); turn `calm.haptics` on with the system haptics on, then off (owner action); play music in another app with `calm.sound` on. Close and reopen the experience. | nothing sounds, moves or vibrates with the defaults; the tone is silent with the silent switch on and audible with it off; other audio keeps playing; no haptic with the person's switch off; the switches are restored as set after reopening | pending device campaign |
| ZG-D8 | Accessibility audit | D1, D2, D3 | Run the system accessibility audits (`VC_RUN_AUDITS=1` only on devices, owner ruling of 2026-11-13) on the Digital Zen Garden screen, its controls, the library and the calm switches, at the default and the largest text size. | no audit issue in the Digital Zen Garden screens at either size | pending device campaign |
