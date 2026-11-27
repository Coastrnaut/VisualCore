# Data model: R02-G21-08

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensGolden.Frame` | name, level, tier, time, actions, tick | 17 frames in fixed order (below) |
| Frame description | identity, positions, counts, values, colours, materials (below) | JSON, sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with the switch (below) |
| Solver regression record | level, replay, prefixes, plan, counterexample, work | all equal to the witness's |
| Alteration | kind (13), level (1, 41, 81), world or star index | fails naming level and part |
| Memory cycle | cycle 1 … 12, footprint, liveObjectCount | 0 objects; 16 MB bound when isolated |

**Frames.** Levels 1, 21, 41, 61 and 81 × tiers 0, 1, 2, then level 25 at tier 0, each at time 0 after the witness's
actions (the certified plan, not the run) with tick 24 shown; then `hero` at tier 0: the level the hero scenario opens
(seed `manifestSeed`) after the certified plan, with tick `heroTick(level)`. Names `level-NNN-tier-T` and `hero`.

**Description.** Identity: name, level, tier, width 1,152, height 768, quantum 8, tick, tilt. Positions ([x, y] in
1/8 pixel, null for a point behind the eye or a missing element): barycentre, worlds (world order), stars (two),
gaugeMargin, firstActionsBar, firstTiltPip (null without a tilt dial). Counts: rings, starRings (rings a star stands
on), worlds, worldsByBand [5] and cellsByBand [5] (lethal low, dim, comfortable, bright, lethal high at the shown tick;
cells over all worlds), shortBrackets, tiltPipsLit, tiltPips, luminosityPipsLit, luminosityPips, actionsLit, actions,
broken. Values: stars [{ring, phase, luminosity}]; windows [{integral, window, start}] per world. Colours: every entry
of `BinaryGardensPalette.all` (27 today) as {name: [r, g, b]} in 8-bit sRGB. Materials: every entry of
`BinaryGardensShaders.materials` (42 today, codes 0 … 41) as [{code, name, constant}].

**Manifest.** `Packages/ExperiencesRound02/BinaryGardens/golden-frames.json`; each digest is the SHA-256 hex of its
description's sorted-key JSON; written only with `BINARY_GARDENS_WRITE_GOLDEN=1`, first after R02-G21-04 … 07 are
recorded; a missing, unreadable or incomplete file fails naming the file and the frame.

**Solver record.** Generated level equal to the witness's level part by part and by fingerprint; the witness's actions
replay on a fresh play (begun, tutorial dismissed on levels 1 … 3) with equal per-action fingerprints, digests and
report and a win on exactly the final `run` (no proper prefix of the arrangement actions followed by `run` wins);
`plan` at the band's plan length gives the witness's arrangement actions, `arrangementsByDepth[size − 1]` = the
counterexample's `arrangements`, `nearestMiss` and `nearestMissArrangement` = its `nearestMiss` and `arrangement`,
`work` = the difficulty's `work` ≤ `workBound`.

**Alteration kinds.** A world's comfortable band, lethal bound, bloom band, required window or orbit (radius, speed or
phase); a ring radius; a luminosity level; a star's starting ring, phase or luminosity; the lethal tolerance; the
budget (each rebuilt through the level initialiser, the first accepted copy whose fingerprint changes); a plan action;
a witness action, per-action fingerprint or per-action digest; the counterexample's arrangements count. World and star
from seed 2_508; the unaltered input gives no failure.

**Memory cycle.** Open (seed 0, level 1), 3 frames at tier 0, memory warning, 1 frame, close; footprint by
`ProcessMemory.footprint()` after each cycle (unavailable: a named failure); `liveObjectCount` 0 after each warning and
close and positive after the next frame; cycles 2 … 12 within 16 MB of cycle 1 only with
`TEST_RUNNER_BINARY_GARDENS_MEMORY_ISOLATED=1`, printed otherwise.
