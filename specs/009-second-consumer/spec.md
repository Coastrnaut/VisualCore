# Feature Specification: Phase 8 — Reuse Validation with a Second Consumer

**Feature Branch**: `009-second-consumer` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F08 · ID namespace FR-F8##, SC-F8##, T-F8##

**Input**: User description: archived `sources/README.md` §10.10 Phase 8 prompt (verbatim in the invocation), plus the
canonical override: lives in `Harnesses/SecondConsumer` with its own XcodeGen spec (package map, ADR-0003); device
measurements deferred to campaign II (constitution V).

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), best option chosen.

- Q: What are the gameplay constants? → A: Growth to bloom takes 4 s of simulated time; minimum spacing between flowers 40 world units (points at zoom 1); a tap within 30 units of a bloom harvests it; capacity 24 flowers; bloom sheds 30 particles/s; harvest burst 80 particles; breeze = drag velocity scaled, decaying with a 1 s time constant.
- Q: Where does the game model live so it is host-testable? → A: In a small local Swift package `Harnesses/SecondConsumer/GardenKit` (depends only on VisualCoreMath and VisualCoreSimulation), tested with `swift test` on the Mac; the app target renders it. This also demonstrates the app-domain pattern the 25 apps will follow (domain logic in a host-testable package).
- Q: How does the documented-API check decide what is "documented"? → A: `scripts/check_documented_api.py` collects every public type and free function declared in VisualCore package sources, finds which of them the consumer's sources reference by name, and requires each referenced name to appear in a VisualCore package README or a `specs/*/contracts/*.md` file; it fails listing undocumented names. Fixtures exercise a pass and an undocumented-use failure.
- Q: How is the dependency check reused for a target outside the root project? → A: The four-layer `audit_showcase_dependencies.py` is run with `--spec Harnesses/SecondConsumer/SecondConsumer.yml --target SecondConsumer --sources Harnesses/SecondConsumer`; package paths are resolved relative to the spec file's directory (needed for harness specs), and it also runs as a post-build phase of the game target.
- Q: Apply the `/speckit-analyze` remediation (C1 rotation and C2 Reduce Motion cases in the smoke test)? → A: Yes, applied 2026-11-10 (no critical findings).
- Q: Is any game state persisted between launches? → A: No; the garden and score live for the session only (no storage, no network, no permissions). Background time is not simulated: the fixed-step clock's accumulator is reset on return to the foreground.

## User Scenarios & Testing *(mandatory)*

Users: a person playing a tiny, calm generative game ("Lumen Garden"), and the maintainers, who use it as proof that
VisualCore is a reusable framework rather than a refactoring of ProjectM.

### User Story 1 - Play a small generative game (Priority: P1) 🎯

A person taps the dark field to plant glowing seeds. Each seed grows into a flower that blooms over a few seconds and
sheds drifting light particles; tapping a fully bloomed flower harvests it, scores a point and releases a burst. A
drag across the field blows a breeze that bends the drifting particles. The field is drawn with its own shader and
a soft glow effect.

**Independent Test**: A UI smoke test plants, waits for blooming, harvests, and reads the score and garden state from
accessible diagnostics.

**Acceptance Scenarios**:

1. **Given** an empty garden, **When** the person taps three places, **Then** three seeds appear and the planted count is 3.
2. **Given** a planted seed, **When** its growth time passes, **Then** it is in bloom and sheds particles.
3. **Given** a flower in bloom, **When** the person taps it, **Then** it is harvested, the score increases by 1 and a particle burst appears.
4. **Given** drifting particles, **When** the person drags across the field, **Then** the breeze direction follows the drag.
5. **Given** a seed that is still growing, **When** tapped, **Then** nothing is harvested (score unchanged).

---

### User Story 2 - Built only on documented VisualCore APIs (Priority: P1)

A maintainer checks that the game uses only documented VisualCore APIs for rendering, resources, shaders, effects and
input, and depends on nothing ProjectM-related.

**Independent Test**: A dependency check (project spec, packages, imports, built binary) and a documented-API check
(every VisualCore symbol the game uses appears in the package documentation) both pass; contaminated or
undocumented-use fixtures fail.

**Acceptance Scenarios**:

1. **Given** the game's project, **When** the dependency check runs, **Then** it reports no ProjectM engine, preset or bridge dependency.
2. **Given** the game's sources, **When** the documented-API check runs, **Then** every VisualCore type and member it uses is documented in a VisualCore package README or contract; a fixture using an undocumented symbol fails.

---

### User Story 3 - Build and run smoke test (Priority: P2)

A maintainer runs one command that builds the game and runs its smoke test on both supported simulator runtimes.

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** the smoke test runs on iOS 27.2 and 26.5 simulators, **Then** the game launches, renders frames without errors and the gameplay scenario passes.

### Edge Cases

- Tapping where a flower already grows does not plant a second one on top (minimum spacing).
- More than the garden capacity (24 flowers): the oldest harvested spot is reused; planting beyond capacity is refused with a visible hint.
- Background/foreground: growth does not jump forward by the time spent in the background (accumulator reset on return).
- Reduce Motion: drifting particles are fewer and slower, no screen-wide bursts; growth still completes.
- Rotation/resize: flowers keep their world positions; touches map correctly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F801**: The game MUST live in `Harnesses/SecondConsumer` with its own project specification and depend only on VisualCore packages; it MUST NOT reference ProjectM engine, preset or reference-bridge modules.
- **FR-F802**: It MUST render through the VisualCore render host and use VisualCore's documented APIs for: resources/shaders (its own bundled background shader through the shader library), primitives and particles, an effect graph (glow), input (tap and drag recognizers, coordinate mapping) and deterministic timing.
- **FR-F803**: Gameplay: plant on tap (minimum spacing 40, capacity 24), growth over 4 s to bloom, bloomed flowers shed 30 particles/s, a tap within 30 of a bloom harvests it (+1 score, 80-particle burst), drag sets the breeze force (decays with a 1 s time constant).
- **FR-F804**: Game state MUST be a pure, host-testable model in the local package `GardenKit` (planting, spacing, capacity, growth, harvest, score, breeze) advanced on a fixed step with a seeded random generator; the session state is not persisted.
- **FR-F805**: Accessible diagnostics MUST expose planted, blooming, harvested/score and particle counts for UI tests, plus VoiceOver labels and a Reduce Motion behavior.
- **FR-F806**: A dependency check MUST prove the game has no ProjectM dependency (the four-layer audit run on the harness spec, with package paths resolved relative to the spec, also as a post-build phase), and `scripts/check_documented_api.py` MUST prove every VisualCore public type/function the game references is named in a package README or feature contract; both MUST fail on contaminated fixtures.
- **FR-F807**: A build/run smoke test MUST build the game and run its UI test on iOS 27.2 and 26.5 simulators.

### Key Entities

- **Garden**: capacity, minimum spacing, flowers, score, breeze.
- **Flower**: id, position, planted time, growth duration, stage (seed → growing → bloom → harvested).
- **DocumentedAPI report**: symbols used, documented, undocumented.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F801**: The gameplay smoke scenario (plant 3, bloom, harvest 1, breeze) passes on both simulator runtimes with the score reaching exactly 1.
- **SC-F802**: The dependency check reports 0 ProjectM items; the documented-API check reports 0 undocumented VisualCore symbols; each contaminated fixture is detected.
- **SC-F803**: The game model's planting, spacing, capacity, growth, harvest and determinism rules are covered by host tests that pass.
- **SC-F804**: The game uses at least five VisualCore capability areas (host, shader library/resources, primitives/particles, effects, input/timing).

## Assumptions

- Simulator results are functional only; frame pacing on D1–D3 is campaign II.
- The game is a harness (not an App Store product); bundle id `dev.visualcore.harness.SecondConsumer` per the owner-approved pattern.
- "Documented" means the symbol is named in `Packages/VisualCore/README.md`, `Packages/VisualCoreRendering/README.md` or a feature contract under `specs/*/contracts/`.
