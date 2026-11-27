# Data model: R02-G21-04

## Entities

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensViewOrbit` | yaw, pitch (radians) | yaw within ±60° about +z through (0, −0.35, 0), pitch −20° … +35° about the authored right axis (+x) through the look-at point; authored = (0, 0); a non-finite angle clamps to 0; not saved |
| `BinaryGardensStarFreedom` | ring, phase, luminosity (Bool) | copied from the level's `BinaryGardensStar` `ringAdjustable`, `phaseAdjustable`, `luminosityAdjustable`; presentation copy only |
| `BinaryGardensSceneSnapshot` (added fields) | `starSpeed` (ω 1 … 3), `freedoms` (2 entries), `preview` (nil by default), `inspectedWorld` (nil by default) | the initialisers set no preview and no inspection, so 503's drawing is unchanged; none of it is in the digest |
| `BinaryGardensPreview` | `change` (a `BinaryGardensAction`: ring, phase, luminosity or tilt), `outcome`: accepted(arrangement, report) or refused(`BinaryGardensError`) | computed with the kernel's `BinaryGardensSky.changed` then `report`; refusal order as the play: `changed`'s `.action(name)` (range, grid, locked, unchanged, separation), then `.budget` when no action is left; unchanged, `.run` or a level of another shape → no preview; presentation only |
| `BinaryGardensPick` | gauge(world), pips(star), star(star), world(world), ring(index), dial, disc, empty | the target drawn last wins (see the picking order) |
| `BinaryGardensStarDragMode` | ring, phase | decided once per drag; nil (explain) when both locked |
| `BinaryGardensGestureController` | state (idle, starPress, ringDrag, phaseDrag, pipsPress, luminosityDrag, dialPress, tiltDrag, gaugePress, scrubDrag, worldPress, ringPress, discPress, emptyPress, orbiting, cancelled), touched target, touch-down snapshot, start and last points, travel, press time, drag mode, last target, last read tick, preview showing, last tap's time and place, orbit, active touches | thresholds: tap 10 pt and 0.5 s, drag 16 pt, double tap 0.35 s and 22 pt, step travel 32 pt, tangent floor 0.5 pt, orbit 90° per width and 60° per height |
| `BinaryGardensGestureAction` | setRing(star, index), setPhase(star, step), setLuminosity(star, index), setTilt(step), showTick(tick), inspectWorld(world?), selectStar(star), preview(change), clearPreview, resetView, explain(reason) | kernel actions only while playing (touch-down and releasing snapshots); `clock.show` and inspection in any stage; mapped onto `star.ring`, `star.phase`, `star.luminosity`, `orbit.tilt`, `clock.show` |
| Presenter mirror (added) | `preview` (`BinaryGardensAction?`), `inspectedWorld` (`Int?`), `phaseTarget` (0 … 48 − g, on the grid) | cleared at an opening, `level.next`, reset and restore (with the orbit back to authored and the adapter's tick 48) |

## Positions the picker reads (confirmed in `BinaryGardensSceneGeometry`, R02-G21-03)

World units; the kernel's base plane is z = 0 (x right, y away from the viewer, z up); fit scale k = 0.95 / R, R the
largest of the level's ring and world radii; kernel points (scale 2²⁰) drawn at k · (x, y, z) / 2²⁰.

| Target | Geometry (constant names) | Pick region |
|---|---|---|
| Star i disc | centre `starCentre(i, s)` = k · `starPositions[t − 1][i]` / 2²⁰, t the shown tick; the star stands at table step (θᵢ + ω·t) mod 48 on ring ρ at tilt τ: (ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]); radius r = `starBaseRadius` 0.05 + `starRadiusStep` 0.012 · L (L the luminosity index, clamped 0 … 3) | projected r + 12 points |
| Star i luminosity pips | n = luminosity levels (1 … 4); pip k centre = c − up · (r + `starPipGap` 0.03) + right · (k − (n − 1) / 2) · `pipStep` 0.022, with w = unit(eye − c), right = unit(ẑ × w) (+x when degenerate), up = w × right — eye = the drawn eye; shape half `pipRadius` 0.008; drawn after the disc | within 12 points of the projected segment pip 0 … pip n − 1 (a point when n = 1); checked before the disc |
| World j | centre `worldCentre(j, s)`; radius `worldRadius` 0.07; its j + 1 pips (0.095 below, 0.022 apart) are not targets | projected 0.07 + 12 points |
| Star ring i | 48-gon, vertex m = `ringVertex(radius: ρᵢ, step: m, tilt: τ, scale: k)` | within 12 points of the projected polygon; later ring indices first |
| Tilt dial (T_max > 0) | pip s centre `tiltPipCentre(s)` = (−1.15 + 0.05 · s, 1.08, 0), s = 0 … T_max (`tiltDialStart`, `tiltPipStep`); shape half `tiltPipRadius` 0.015; drawn before the rings | within 12 points of the projected segment pip 0 … pip T_max |
| Gauge row j | centre line y_j = `gaugeTop` −1.2 − `gaugeStep` 0.1 · j; plate x `plateLeft` −0.95 … `plateRight` 1.22, y_j ± `plateHalf` 0.045, z 0; tick cell t centre x = −0.9 + (t − 0.5) · 1.8 / 48 (`cellX`), 0.8 · 1.8/48 wide; tick marker at (cellX(shown), y_j + 0.048); bloom meter x `bloomStart` 0.97 … `bloomEnd` 1.2 | finger cast onto z = 0 inside the plate rectangle (plates are disjoint; the 0.01 gaps are empty) |
| Actions bars | y = −1.2 − 0.1 · W − 0.03 (`actionsY`), x −0.9 … 0.9, 0.035 tall | empty space |
| System disc | radius `discRadius` 0.95 about the origin on z = 0 | finger cast onto z = 0 within 0.95 |
| Camera | authored eye (0, −2.0, 3.2), look-at (0, −0.35, 0), up +y; box x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85; `fitMargin` 0.06; aspects 0.4 … 2.5 | orbit pivot = box centre (0, −0.35, 0); `refitMargin` 0.06; eye distance ≥ ≈ 3.60 |

## Derived values

| Value | Rule |
|---|---|
| Star table step at tick t | (θ + ω · t) mod 48 (`BinaryGardensSky.phase`); t = 48 gives θ |
| Projected tangent u | view point of ring vertex (step + 1) − view point of ring vertex (step − 1), same ring and tilt; |u| < 0.5 points → ring drag |
| Drag mode | along = |travel · û|, across = |travel − (travel · û) û|; along > across → phase, else ring; locks override |
| Ring target | argmin over ring indices i of |view(ringVertex(ρᵢ, step, τ)) − finger|; lower index on ties |
| Phase target | argmin over p ∈ {0, g, …, 48 − g} of |view(ringVertex(ρ, (p + ω·t) mod 48, τ)) − finger|; lower p on ties |
| Pip / dial tap | argmin over pips of |projected centre − finger|; lower index on ties |
| Step drag value | clamp(start + round(dx / 32), 0, upper); halves away from zero; upper = n − 1 or T_max |
| Tick under the finger | clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48), x the cast x clamped to −0.9 … 0.9 |
| Orbit from two fingers | yaw += Δx / width · 90°, pitch −= Δy / height · 60°, clamped |

## State transitions (controller)

idle → (one finger down, picked) starPress | pipsPress | dialPress | gaugePress | worldPress | ringPress | discPress |
emptyPress; starPress → ringDrag | phaseDrag (travel ≥ 16 while playing and a free mode); pipsPress → luminosityDrag;
dialPress → tiltDrag; gaugePress → scrubDrag (a tick changed); any one-finger state → orbiting (second finger; clears a
preview); orbiting → cancelled (a finger lifts while others stay) → idle (every finger lifted); any → idle on release
or `.cancelled` (a cancel sends only `clearPreview` when a preview was showing).
