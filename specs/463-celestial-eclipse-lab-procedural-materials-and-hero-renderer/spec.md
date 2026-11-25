# Feature Specification: R02-G17-03 — Celestial Eclipse Lab: procedural materials and hero renderer

**Feature Branch**: `463-celestial-eclipse-lab-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-25

**Status**: Draft

**Ledger gate**: R02-G17-03 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1703-###,
SC-R02G1703-###, T-R02G1703-###

**Input**: User description: the archived R02-G17-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Celestial Eclipse Lab (code-only
hero: "glowing planetary crescents eclipsing into razor-edge corona halos"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/463-celestial-eclipse-lab-procedural-materials-and-hero-renderer`;
  FR-R02G1703-###, SC-R02G1703-###, T-R02G1703-###.
- **Packaging (ADR-0009):** the source's `Apps/CelestialEclipseLab` becomes the experience target
  `CelestialEclipseLabExperience` (with its tests) in `Packages/ExperiencesRound02/CelestialEclipseLab/Experience`
  beside the existing `CelestialEclipseLabCore` (the source's `Packages/GameModules/CelestialEclipseLabCore`); the experience
  `r02-g17.celestial-eclipse-lab` (free) is registered in the catalog as a candidate (not available) and linked into the
  one app, as Starlit Cartouche was at R02-G16-03; it becomes available only at its gate X-R02-G17.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 74" is a milestone figure — the catalog is
  the 100 certified levels of R02-G17-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G17-01 and -02.
- **Model:** feature 453 (Starlit Cartouche's hero renderer and experience).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch glowing planets eclipse into corona halos (Priority: P1) 🎯

A player opens Celestial Eclipse Lab and sees miniature planets on their orbital rings over an ink-navy sky, seen from
one side. As the predicted clock is stepped, a nearer planet slides across a farther one: its shadow cuts a precise
crescent from the glowing disc, and when the cover is total or annular a razor-edge corona halo flares in gold. Below
the sky a timeline shows the target eclipses with their windows and the eclipses the current phases predict.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose planets, rings,
crescents, timeline and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose planet, ring,
   timeline and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the planets move to their orbit
   positions at the shown tick for the new phases, the timeline shows the new prediction, and the win or failure shown
   matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown tick or rendering failure, the drawn image never changes
the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn planets sit at the
kernel's exact orbit positions for the shown tick.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown tick and frame count never changes the kernel's digest; a
failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses flat planet discs and no glow but keeps the same objective, planets, rings, crescents,
timeline, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the planets, rings, timeline and gauges at the same places; only the planet
shading detail and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G17.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every orbit, the timeline and the gauges with a margin of at least 5 % on
  each side.
- **Colour-blind players:** each planet carries (index mod 6) + 1 notches on its ring, fixed planets a square frame,
  the chosen planet a dashed ring, matched predicted eclipses a filled mark and unwanted ones a cross, windows brackets,
  and actions a row of bars; every body, eclipse and measure can be named in words by the kernel, so no information is
  carried by hue only.
- **A failure (unwanted eclipse, an eclipse outside its window, or the horizon reached):** the failing event is marked
  on the timeline in the broken colour and the two planets involved are outlined; the failure shown names it, as the
  kernel's reason does.
- **A won level:** every target mark is lit and the corona halos of the matched eclipses flare; the frame checks use the
  same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the shown tick does not auto-advance and halos do not pulse; Reduce Flashing caps the glow to the
  shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1703-001**: The experience MUST render the planets as generated sphere meshes at their orbit positions for
  the shown tick, the orbital rings, the eclipse crescents and corona halos, the timeline and the gauges entirely from
  generated geometry and shader code, with no image assets.
- **FR-R02G1703-002**: Materials MUST show an ink-navy sky, glowing planetary discs with procedural layered shading,
  precise shadow crescents where a nearer planet covers a farther one, and corona-gold halos with muted-ember accents,
  computed in shaders; every element also has its shape or pattern.
- **FR-R02G1703-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown tick or failure may change the kernel's state, digest or verdict.
- **FR-R02G1703-004**: The experience MUST offer three quality tiers that change only planet shading detail and glow,
  never planets, rings, crescents, timeline, colours, objective or indicators; the selected tier and the reason MUST be
  logged.
- **FR-R02G1703-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for changing a phase, running the clock, undo, redo, next level, choosing the shown planet and the shown
  tick, digest, snapshot and restore), opening certified levels of R02-G17-02.
- **FR-R02G1703-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1703-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1703-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1703-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the bodies (positions at the shown tick for the current phases, radii, fixed flags), the orbits,
  the eclipses under way at the shown tick with their visibility classes, the target with windows, the predicted
  timeline and matched count, the shown tick and horizon, the chosen planet, stage, failure, actions left, budget, level
  number and presentation time.
- **Sky geometry**: the planet spheres, orbital rings, crescent masks, corona halos, the timeline and the gauges.
- **Quality tier**: 0, 1 or 2, with its planet shading detail and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1703-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: planet,
  ring, timeline and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1703-002**: Across 200 seeded snapshots, tier changes, time steps, shown-tick changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G1703-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1703-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1703-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1703-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag orbital handles, rotate the time dial, step the predicted timeline, orbit) are R02-G17-04; hints and
  progression R02-G17-05; accessibility and polish R02-G17-06; persistence R02-G17-07. This feature gives the experience
  a minimal control panel (planet −/+, phase −/+, tick −/+, run, undo, redo, next level, each labelled) so it can be
  exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Analytic orbital
  rings, signed circle masks and eclipse glow shaders" are generated rings through the kernel's exact orbit positions, a
  crescent mask computed from the nearer disc's projected circle, and an emissive halo pass; the eclipse drawn is always
  the eclipse judged.
- Like Starlit Cartouche, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G17-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G17-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g18.apsides-workshop`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (analytic orbital rings, signed circle masks and eclipse glow shaders) | FR-R02G1703-001 |
| Signature shader (precise shadow crescents over glowing planetary discs; procedural planets, layered spheres and emission shaders) and palette (corona gold, ink navy and muted ember) | FR-R02G1703-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1703-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1703-004 |
| Renderer purity, stability | FR-R02G1703-003; SC-R02G1703-002, 003 |
| Real render captures | FR-R02G1703-006 |
| "Register it in the catalog" (override) | FR-R02G1703-008 |
| No Stage One breakage | FR-R02G1703-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G17.
