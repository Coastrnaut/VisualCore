# Digital Aquarium — device campaign plan

**Status: nothing measured on a device.** Every result below is pending. Feature 072 (A09-P05, FR-A09-540, task
T-A09-508); carried out in A09-P06's {device} task. Digital Aquarium (`a09.digital-aquarium`) is measured as a row of the
one VisualCore app's device campaign (Auto-Creator.md section 23), not as a separate app. Simulator results — the
schooling, feeding, water-effects, budget, dimmer and long-run suites, the reopen test and the render tests — are
development signals only and never device evidence.

## When and in which order

1. Not before the gate `ImplementationLock-100` is recorded: `python3 scripts/migration_ledger.py guard-device` must
   exit 0. No install, launch or test of the app on a physical device happens earlier.
2. The owner has provisioned signing, paired, trusted and unlocked the devices and answers every system prompt that
   needs a person (owner steps; otherwise the row is `BLOCKED_OWNER_ACTION`). The agent never taps a trust prompt.
3. Order: **D1** (iPhone 15), then **D2** (iPad Pro 13-inch M5), then **D3** (iPad A16). **D3 stays on iPadOS 26.5
   and is never updated**; if it reports another version, its campaign is blocked and the owner is told.
4. Every measurement uses short runs; only the thermal row lasts ten minutes, as the plan of the one app's campaign
   asks. Longer behaviour is bounded by arithmetic from the short runs. Hardware identifiers go only to untracked
   private files.

## Measurements

The quality levels are configured budgets, not measurements: level 0 → 24 bubbles per vent, 24 motes, two-octave
caustics; level 1 → 12, 12, one octave; level 2 → 6, 6, no caustics. Ambient drawing (ambient mode, Low Power Mode or
Reduce Motion) caps them at 12, 12, two octaves and dims the scene to 60 % after 60 s without a touch.

| Measurement | Devices | Procedure | Pass criterion | Result |
|---|---|---|---|---|
| Frame time per level | D1, D2, D3 | Reef and Kelp, swimming, with food and with ambient on; pin the host's quality level to 0, 1 and 2 and record CPU and GPU time per frame over a short run; first run and warm runs separate. Source: `PerformanceRecord.pacing`, `qualityLevel`, `qualityPinned` | At the level the governor settles on, CPU and GPU time each stay within the display's refresh interval except isolated spikes; every lower level is at least as fast as the level above | pending |
| Settled quality level | D1, D2, D3 | Automatic mode with feeding and editing; record the level the governor settles on and each change with its cause. Source: `PerformanceRecord.qualityLevel`, `stepsDown`, `stepsUp` | The governor settles; every step has a recorded cause; the aquarium's state and digest never change from the steps | pending |
| Thermal state over ten minutes | D1, D2, D3 | Ten minutes of ambient mode, not charging; record `PerformanceRecord.thermal`, `lowPower`, the level and the frame intervals each minute | The thermal state never reaches critical; when it rises the level steps down instead of frames being dropped | pending |
| Ambient dimming | D1, D2, D3 | Ambient on, no touch for 60 s, then a tap; Low Power Mode on and off; record the scene brightness steps and the system brightness before and after | The scene fades to 60 % over about 2 s after 60 s and restores on the tap; Low Power Mode selects the ambient drawing; the system screen brightness never changes | pending |
| Memory | D1, D2, D3 | After every level has been drawn, after five feeds, after twelve saved aquariums are written and opened, after leaving and reopening the experience five times: `PerformanceRecord.memoryFootprintBytes`, `gpuBytes`, `memoryEvents`; `ResourceRegistry` counts | No growth across repeated reopenings, feeds and openings of saved aquariums; render resources return to the host's baseline after leaving | pending |
| Saved aquariums and lifecycle | D1, D2, D3 | Save three aquariums, relaunch, open each, delete one; background and foreground while food sinks; inspect the app container (owner-held copy) | The configurations survive relaunch exactly; only `aquarium-<uuid>.json` files and the app's `state.json` are in the experience's folder; a suspension never fast-forwards the fish or the food | pending |
| Gestures | D1, D2, D3 | Tap to feed, long-press to place, drag a piece, two-finger touches, with VoiceOver off and on | Each gesture does only its action; the native controls do the same with VoiceOver | pending |
| VoiceOver and announcements | D1, D2, D3 | VoiceOver on: hear the canvas description in each state (habitat, food, decorations, ambient, paused); feed, edit, change habitat, toggle ambient | The description names every element; announcements at most one per 3 s, only on changes | pending |
| Accessibility system audits | D1, D2, D3 | The system accessibility audits at the default and the largest text size with `VC_RUN_AUDITS=1` (owner ruling of 2026-11-13) | No audit issue in the Digital Aquarium screens | pending |
| Dynamic Type | D1, D2, D3 | Largest accessibility text size; every control section (habitat, lighting, motion, feeding, decorations, ambient, saved aquariums) in portrait and landscape | All text visible or scrollable; every control operable; hit areas at least 44 by 44 points | pending |
| Reduce Motion and contrast | D1, D2, D3 | Reduce Motion on; Increase Contrast on; both habitats at dim and bright lighting, with caustics on and off | Swim motion and bubbles reduced, caustics still; fish, plants, decor and food distinguishable from the water in every combination | pending |

Each row is recorded pass, fail or `BLOCKED_OWNER_ACTION`; skipped is never success. No measured value of Digital
Aquarium is claimed anywhere until its row passes.
