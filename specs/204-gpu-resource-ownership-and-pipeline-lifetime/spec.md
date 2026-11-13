# Feature Specification: R02-F04 — GPU resource ownership and pipeline lifetime

**Feature Branch**: `204-gpu-resource-ownership-and-pipeline-lifetime` (spec directory only; work on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: R02-F04 (migration ledger, shared round feature) · ID namespace FR-R02F04-###, SC-R02F04-###, T-R02F04-###

**Input**: User description: the archived R02-F04 `/speckit-specify` prompt (round2.md), verbatim in the invocation, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21, and the owner's rulings of 2026-11-13.

Canonical overrides:
- **Feature directory and ids:** `specs/204-gpu-resource-ownership-and-pipeline-lifetime`; FR-R02F04-###,
  SC-R02F04-###, T-R02F04-###.
- **Section 13 disposition: reuse.** Resource ownership already exists (resource registry, resource ledger and budget,
  render lifecycle); session-level rules are delivered by UA-F03. This feature proves the existing rules with their
  tests, fixes the one defect the audit found, and adds only what games need that is missing: an immutable pipeline
  description applied as one unit, and offscreen targets with depth.
- **Who the users are:** the engineer writing one of the 75 games, who needs programs, targets and render state that
  never silently disappear or leak between frames, scenes and context losses; the player, who must never see a black
  or wrong frame because a cache dropped something in use; the verification runner, which reads resource counts at
  session close.
- **Owner rulings of 2026-11-13 that bind this feature:** tests are short; system accessibility audits wait for the
  device campaign; independent files are fanned out to parallel agents.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** GPU memory actually used on devices (simulator byte counts are
  accounting, not device evidence) — one {device} task. **Owner-only items:** none.
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/R02-F04-audit.md`, names re-verified):**
  - Per-context residency: every GPU handle carries the context generation; the registry rejects stale handles,
    releases everything and counts leaks when a context ends, and rebuilds after context recreation.
  - Caches: compiled programs are cached by a content key with least-recently-used eviction at 64 entries; render
    targets are pooled. **Defect:** eviction deletes the evicted program on the GPU even when a scene still holds it;
    that scene's next draw with it silently does nothing (a black frame). An existing test asserts the deletion.
  - Budgets per session; main-thread ownership; ordered destruction (frames stop → scene teardown → registry release
    → surfaces → context); leak, live and stale counts at session close; a lifecycle state machine.
  - Missing for games: no immutable description of a draw's pipeline state (program plus blend, depth, cull and colour
    mask) — render state is only reset; offscreen render targets are colour-only (the renderbuffer kind exists but is
    never used).
  - An internal hook called when a context ends is never assigned (no consumer).

## Absorbed source requirements

| Source item (R02-F04 prompt) | Disposition | Reason / where |
|---|---|---|
| Per-context residency | Adopted (reuse) | Existing generation checks; FR-R02F04-001 proves them with the existing tests |
| Resource caches | Adopted | Program cache and target pool reused; eviction defect fixed (FR-R02F04-010..013) |
| Immutable descriptors | Adopted | FR-R02F04-020..024 (pipeline description) |
| Main loop ownership | Adopted (reuse) | Main-thread rule; FR-R02F04-002 |
| Destruction ordering | Adopted (reuse) | Existing order; FR-R02F04-003 |
| Depth for 3D games (implied by "pipeline") | Adopted | FR-R02F04-030..033 |
| Schema migration | Superseded | No persisted data in the resource layer |
| Accessibility | Adapted | Not applicable to the resource layer; recorded |
| Observability | Adopted (reuse) | Ledger snapshot (live, leaked, stale counts) and the new eviction counter (FR-R02F04-013) |
| Copyright and originality | Adopted | All code in the repository; no third-party assets |
| USD 1.99–4.99, Round 2 lock | Superseded | ADR-0009, ImplementationLock-100 |

## Clarifications

### Session 2026-11-13

- Q: How does the registry know that an evicted program may still be in use? → A: It does not count holders.
  Eviction only removes the program from the cache and moves it to a retired set; it is deleted when the holder
  releases it or when the context ends (the registry releases the retired set with everything else). A later request
  for the same variant compiles a new program. No reference counting and no deletion from a destructor.
- Q: Where does the pipeline description live? → A: A pure value `RenderState` (blend, depth test, depth write,
  cull, colour mask; Hashable, with presets) in the pure shader-source module, host-tested; the rendering package adds
  `Pipeline` (a program plus a `RenderState`, equal when the program is the same object and the states are equal)
  and `GLState.apply(_:)`, which sets every field and returns false for a stale or released program.
- Q: Which depth storage do depth targets use? → A: A 24-bit depth renderbuffer of the target's size (no stencil),
  requested by a `depth: Bool` option of the existing target factory (default false, so existing callers are
  unchanged); counted as the existing `renderbuffer` resource kind; pooled targets are keyed by size, format and
  depth.
- Q: How is a refused draw counted? → A: With the ledger's existing stale counter (`noteStale`), so session-close
  diagnostics and evidence report it without a new field; the registry's eviction count is a new statistic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A program in use is never deleted by the cache (Priority: P1)

A game compiles many shader variants (more than the cache holds). A variant the game still uses keeps drawing
correctly even after the cache evicted it; a variant nobody uses is freed.

**Why this priority**: today the eviction produces a silent black frame in any game with more than 64 variants.

**Independent Test**: create 65 variants while holding the first; draw with the first and read back pixels; release it
and check the live count; end the context and check zero leaks.

**Acceptance Scenarios**:

1. **Given** a scene holding program P and creating 64 more variants, **When** P is evicted from the cache and then
   used to draw, **Then** the draw produces the expected pixels.
2. **Given** an evicted program, **When** its holder releases it, **Then** it is deleted and the live program count
   drops by one.
3. **Given** evicted programs nobody released, **When** the context ends, **Then** all are deleted and the ledger shows
   zero live and zero unexpected leaks for programs the registry owns.
4. **Given** the same variant requested after eviction while the old program is still held, **When** it is requested,
   **Then** the caller receives a working program (the held one or a new one) and the counts stay consistent.

---

### User Story 2 - One immutable description of a draw's pipeline (Priority: P1)

A game author describes a draw's pipeline once (which program, blending, depth test and write, face culling, colour
mask) as an immutable value, and applying it always leaves the renderer in exactly that state.

**Why this priority**: games mix opaque 3D, transparent and additive passes; state left over from the previous draw is
the most common source of wrong frames.

**Independent Test**: apply two different descriptions in turn and read the renderer state back after each; apply a
description after random state changes and read it back.

**Acceptance Scenarios**:

1. **Given** a description with alpha blending, depth test on and depth write off, **When** it is applied, **Then** the
   renderer reports exactly those settings.
2. **Given** any prior render state, **When** a description is applied, **Then** the resulting state depends only on
   the description.
3. **Given** two descriptions equal in every field, **When** they are compared, **Then** they are equal and hash
   equally, so they can key a cache.
4. **Given** a description naming a program from an ended context, **When** it is applied, **Then** the draw is refused
   and counted as a stale use, never drawn with a wrong program.

---

### User Story 3 - Offscreen targets with depth (Priority: P2)

A 3D game renders a scene with correct occlusion into an offscreen target (for post effects), so the target needs a
depth buffer that lives and dies with it.

**Why this priority**: the 3D games of rounds 2–4 need depth for any offscreen pass.

**Independent Test**: render two overlapping quads at different depths into a depth target in the wrong order and
read back that the nearer one wins; release the target and check the ledger.

**Acceptance Scenarios**:

1. **Given** a target created with depth, **When** two overlapping triangles are drawn far-then-near and near-then-far,
   **Then** the nearer colour wins in both orders.
2. **Given** a depth target, **When** it is released or its context ends, **Then** its colour and depth storage are
   both freed and counted.
3. **Given** a depth request the device cannot satisfy or a size beyond the limits, **When** the target is created,
   **Then** creation fails with a reason and nothing is left allocated.

---

### User Story 4 - The existing ownership rules are proven (Priority: P2)

The owner needs evidence that the existing rules — per-context residency, stale rejection, main-thread ownership,
ordered destruction, budgets and leak counts — still hold.

**Why this priority**: reuse needs proof, not a document.

**Independent Test**: run the existing registry, lifecycle, recreation and session-close tests on both simulator
runtimes and record them.

**Acceptance Scenarios**:

1. **Given** the existing tests, **When** they run on the iOS 27.x and 26.5 simulators, **Then** all pass.
2. **Given** a session that opens and closes an experience, **When** it closes, **Then** live counts are zero.

### Edge Cases

- **Context loss mid-frame:** programs, targets and depth storage of the old generation are rejected and rebuilt;
  no stale handle is used.
- **Eviction while drawing:** a program evicted during a frame stays valid until its holder releases it.
- **Budget exceeded:** creating a depth target over the session budget fails with the budget error and allocates
  nothing.
- **Many variants:** the cache stays bounded at 64 cached programs; retired programs are bounded by what scenes hold.
  A scene that drops an evicted program without releasing it leaves it retired until the context ends, where it is
  released by the registry (registry-owned, so not counted as a scene leak), the same as cached programs today.
- **Memory pressure and backgrounding:** handled by the existing session lifecycle (UA-F03); this feature adds no new
  state that survives a context.
- **Corrupted or newer-version data:** not applicable (nothing persisted).
- **Cancellation:** not applicable (all calls are synchronous on the main thread).

## Requirements *(mandatory)*

### Functional Requirements

**Reuse (story 4)**
- **FR-R02F04-001**: Handles MUST stay tied to their context generation; stale handles MUST be rejected and counted
  (existing behavior, proven by the existing tests on both runtimes).
- **FR-R02F04-002**: Resource creation and release MUST stay on the main thread (existing rule).
- **FR-R02F04-003**: Destruction MUST keep the existing order (frames stop, scene teardown, registry release, surfaces,
  context) and session close MUST report zero live resources.

**Program cache (story 1)**
- **FR-R02F04-010**: Evicting a program from the cache MUST NOT delete it; it moves to a retired set until its holder
  releases it or its context ends.
- **FR-R02F04-011**: An evicted program MUST be deleted when its holder releases it or when its context ends,
  whichever comes first.
- **FR-R02F04-012**: The cache MUST stay bounded at its current limit of 64 cached programs.
- **FR-R02F04-013**: The registry MUST count evictions, and the counts at session close MUST show zero live programs.
- **FR-R02F04-014**: The existing test that asserts deletion on eviction MUST be amended with the reason, not deleted.

**Pipeline description (story 2)**
- **FR-R02F04-020**: An immutable pipeline description MUST hold the program and the blend mode, depth test, depth
  write, face culling and colour mask of a draw; equal descriptions MUST compare and hash equal.
- **FR-R02F04-021**: Applying a description MUST set every one of those states, so the result does not depend on the
  previous state.
- **FR-R02F04-022**: Applying a description whose program is stale or released MUST refuse the draw and count it with
  the ledger's stale counter.
- **FR-R02F04-023**: The pure part of the description (everything except the program handle) MUST be host-testable.
- **FR-R02F04-024**: Presets MUST exist for the common cases: opaque, alpha-blended, additive and opaque 3D with depth.

**Depth targets (story 3)**
- **FR-R02F04-030**: An offscreen render target MUST be creatable with 24-bit depth storage of the same size through
  an option that defaults to off.
- **FR-R02F04-031**: The depth storage MUST be counted, released with its target and rejected after context loss.
- **FR-R02F04-032**: Creation MUST fail without residue when the size is outside the limits, the budget is exceeded or
  the framebuffer is incomplete.
- **FR-R02F04-033**: Pooled targets MUST distinguish targets with and without depth.

**Common**
- **FR-R02F04-040**: Every new public declaration MUST have `///` documentation, appear in the API baseline and have
  tests; pure types live in the pure package, GPU code in the rendering package.
- **FR-R02F04-041**: Tests MUST be short (no soak runs); GPU memory on devices is measured only in the device campaign.

### Key Entities

- **Pipeline description:** program reference; blend mode (none, alpha, premultiplied, additive); depth test; depth
  write; cull mode (none, back, front); colour mask.
- **Depth target:** colour storage plus depth storage of one size, owned together.
- **Eviction count:** a counter in the registry's statistics.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F04-001**: With 65 variants and the first one held, a draw with the evicted first program produces the
  expected pixels (0 black frames) and session close shows 0 live programs.
- **SC-R02F04-002**: After applying a description, 100% of its fields read back as set, independent of 3 different
  prior states.
- **SC-R02F04-003**: A depth target resolves occlusion correctly in 2 of 2 draw orders; release frees 2 of 2 storages.
- **SC-R02F04-004**: 100% of the existing registry, lifecycle and recreation tests pass on the iOS 27.x and 26.5 simulators.
- **SC-R02F04-005**: The cache never holds more than 64 programs.
- **SC-R02F04-006**: Every new test finishes in under 5 seconds on the simulator.

## Assumptions

- OpenGL ES 3.0 through ANGLE supports depth renderbuffers (24-bit depth is in the ES 3.0 minimum).
- The pipeline description is applied on the main thread, inside a frame, by the same code that draws.
- R02-F02 and UA-F02 are pass in the migration ledger; session-level budgets are UA-F03's.
