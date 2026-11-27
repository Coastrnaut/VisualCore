# Research: R02-G21-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` equal to the witness difficulty's `work`
  and at most `BinaryGardensSolver.workBound`, 5,000 arrangements judged), the certified actions, the arrangements
  judged at the depth one action short and the nearest miss with its arrangement, never by seconds. Rationale: CI
  runners are about three times slower; a count is stable, and 5,000 is above three times the largest catalog search
  (1,589, level 88).
- **R2 Level identity before replay.** Decision: the solver check first compares the generated level
  (`BinaryGardensExperienceCore.generated(number:)`, the manifest entry's certified candidate) with the witness's level
  part by part (budget, clamp radius, difficulty, id, lethal tolerance, luminosity levels, maximum tilt, minimum
  separation, phase step, ring radii, seed, star speed, stars with freedoms, start tilt, tutorial, worlds) and by
  fingerprint, naming the first differing part. Rationale: a level alteration must be named by its part, not only by a
  changed fingerprint.
- **R3 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (the projected barycentre, world centres, star centres, first gauge plate margin, first actions bar and first
  tilt pip; the counts; the shown tick, tilt, star controls and world windows; the palette and the material table),
  digested with SHA-256 and pinned in the repository. Rationale: no stored pictures (constitution X, XIII); the
  simulator compares rendered pixels with the same description.
- **R4 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal counts, values, colours and materials; each pinned digest must equal the digest of its pinned
  description. Rationale: the system trigonometry may differ in the last bit between macOS releases, and a hand-edited
  description must not pass.
- **R5 Palette and materials whole.** Decision: the description takes every entry of `BinaryGardensPalette.all` (27)
  and of `BinaryGardensShaders.materials` (42, codes 0 … 41, each with its palette constant) in declaration order.
  Rationale: a colour or material added by a prerequisite is pinned with the rest when the baseline is regenerated after
  that prerequisite is recorded (spec edge case).
- **R6 Frame actions and tick.** Decision: a level frame applies all of the witness's actions but not the run, at
  presentation time 0 with the authored camera (`camera(aspect:)`, the view orbit at rest), no preview and no inspected
  world, with tick 24 shown (as the feature-503 frame checks send `clock.show [24]`); the hero frame applies the hero
  scenario's entries (the certified plan and `heroTick(_:)` of the hero level). Rationale: the run is the only action
  that wins, so the frame is never won; coronas, trails, motes and glow move by time or differ by tier and are not
  described.
- **R7 Tilt dial frame.** Decision: level 25 at tier 0 joins the 15 feature-503 frames. Rationale: none of levels 1,
  21, 41, 61 and 81 has a tilt dial (maximum tilt 0); level 25 is the first with the full range 0 … 3 (start tilt 2), so
  the first tilt pip and the lit and total tilt pips are pinned.
- **R8 Groups of ten.** Decision: the solver regression runs 10 parameterised tests of 10 levels. Rationale: the
  heaviest group (levels 81 … 90) judges 9,238 arrangements and the next 7,531; the 100-level catalog tests of feature
  502 run in 20 parallel groups well inside the budget, so ten levels per test leave a margin under the 10 s rule.
- **R9 Alterations.** Decision: thirteen kinds on copies of levels 1, 41 and 81, each level kind rebuilt through the
  level initialiser trying a fixed candidate list in order (the first copy the level rules accept and whose fingerprint
  changes; a refused construction is itself a named failure); the world and star are chosen from seed 2_508 by a fixed
  integer rule (no random source). Rationale: Mushroom Weather's twelve kinds adapted; the star start is added because
  Binary Gardens has a movable start.
- **R10 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R11 Golden only in test builds.** Decision: `BinaryGardensGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and
  is forbidden in the Release binary. Rationale: as `MushroomWeatherGolden` (feature 498).
- **R12 Baseline after the prerequisites.** Decision: the solver regression may be drafted before R02-G21-04 … 07 are
  recorded; the golden manifest is generated and the gate recorded only after all four. Rationale: 505's scenario
  manifest feeds the hero frame, 506's lights and 504's presenter draw the simulator frames, and any palette or material
  addition must be in the pinned description (FR-R02G2108-009).
