# Feature Specification: R02-F03 — Numerical foundations and deterministic seeded scene time

**Feature Branch**: `203-numerical-foundations-and-deterministic-seeded-scene-time` (spec directory only; work on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: R02-F03 (migration ledger, shared round feature) · ID namespace FR-R02F03-###, SC-R02F03-###, T-R02F03-###

**Input**: User description: the archived R02-F03 `/speckit-specify` prompt (round2.md:424), verbatim in the invocation,
with the canonical overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21, and the owner's rulings of
2026-11-13.

Canonical overrides:
- **Feature directory and ids:** `specs/203-numerical-foundations-and-deterministic-seeded-scene-time`;
  FR-R02F03-###, SC-R02F03-###, T-R02F03-###.
- **Section 13 disposition: reuse.** Deterministic time and randomness already exist (fixed-step clock, scene clock,
  time-step policy, fixed-step runner, seeded generator); this feature adds only the missing numeric helpers, each
  with tests and a named consumer, and writes the conventions down. No new clock, hash or module.
- **Who the users are:** the engineer writing one of the 75 games or 25 creative experiences, who needs randomness
  and time that replay identically from a seed and a list of inputs; the verification runner, which compares
  digests of replays; and the player, who sees the same level, puzzle or composition again from the same seed.
- **Owner rulings of 2026-11-13 that bind this feature:** tests are short (golden vectors and small counts, no long
  statistical runs); system accessibility audits wait for the device campaign; independent files are fanned out to
  parallel agents.
- **Superseded parts of the source prompt:** the "USD 1.99–4.99 one-time purchase, no IAP" model (ADR-0009: one free
  app with one USD 1.99 non-consumable); the "Round 2 lock" before devices (ImplementationLock-100). **Device-only
  items:** none (numeric behavior is checked on the host and simulators; the cross-device determinism observation
  belongs to the device campaign of the experiences). **Owner-only items:** none.
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/R02-F03-audit.md`, names re-verified):**
  - Fixed-step time: `FixedStepClock` (accumulator, at most 8 steps per frame, dropped time, invalid-delta count,
    interpolation alpha), `FixedStepRunner`, `TimeStepPolicy`, `SceneClock`; the experience engine counts integer
    steps and each experience core declares a step duration (default 1/120 s, clamped to 1/240…1/30).
  - Randomness: `SplitMix64` and the xoshiro256** generator `SeededRandom` (double, float, range, rejection-sampled
    integer, normal), with golden-sequence tests. Its state is private and cannot be saved.
  - Replay: control streams, experience scenarios and scenario manifests with the seed as decimal text and committed
    digests; the state digest rejects non-finite numbers and writes −0 as 0.
  - Transforms: column-major matrices, counter-clockwise, y-up, right-handed with the OpenGL depth range, stated in
    code comments only.
  - Missing: deriving independent named sub-seeds (experiences add a constant to the seed by hand); shuffle, pick and
    weighted choice with an algorithm the project owns (the standard library's are not guaranteed stable across
    releases); saving and restoring generator state; a CPU twin of the shader hash (`vc_pcg` and `vc_hash*` exist in
    GLSL only); shared helpers for finite checks, quantization, wrapping and angle normalization; one document of
    the determinism rules and transform conventions.

## Absorbed source requirements

| Source item (R02-F03 prompt) | Disposition | Reason / where |
|---|---|---|
| Fixed step clock | Adopted (reuse) | Existing clocks; FR-R02F03-001 keeps their behavior and documents them |
| Seed hashing | Adopted | FR-R02F03-010..013 (named sub-seed derivation) |
| Stable math | Adopted | FR-R02F03-020..023 (owned algorithms), FR-R02F03-050..054 (numeric hygiene) |
| IEEE hygiene | Adopted | FR-R02F03-050..054 and the determinism rules (FR-R02F03-060) |
| Replay logs | Adopted (reuse) | Existing scenarios and control streams; FR-R02F03-002 requires replays to stay byte-identical |
| Transform conventions | Adopted | FR-R02F03-061 (one conventions document) |
| Schema migration | Adapted | Only the new saved generator state has a format; it is versioned (FR-R02F03-031..033) |
| User journeys, acceptance tests, deterministic tests, error handling, observability | Adopted | Stories below; existing clock counters are the observability |
| Accessibility | Adapted | No interface in this feature; recorded as not applicable to numeric helpers |
| Copyright and originality | Adopted | Algorithms are published public-domain designs (SplitMix64, xoshiro256**, PCG hash, Fisher–Yates), implemented in the repository |
| USD 1.99–4.99 purchase, no IAP | Superseded | ADR-0009: free app, one USD 1.99 non-consumable (UA-F05) |
| No device before Round 2 lock | Superseded | ImplementationLock-100 |
| Prerequisite R2-F02 | Met | R02-F02 is pass in the ledger |

## Clarifications

### Session 2026-11-13

- Q: How is a sub-seed derived from a seed and a label or an index? → A: With the SplitMix64 finalizer (the mix
  step of the existing `SplitMix64`): label → finalizer(seed XOR FNV-1a-64 of the label's UTF-8 bytes); index →
  finalizer(seed XOR finalizer(index + 1)). Pure 64-bit integer arithmetic, so identical everywhere; golden values
  are committed. Existing hand-made offsets (A04's `seedStep`) stay unchanged because their digests are committed;
  the new derivation is for new code.
- Q: How many random draws does each owned algorithm consume? → A: Exactly one 64-bit draw per random index, mapped
  to [0, n) by the high half of the 128-bit product (bias at most n/2^64, accepted for exact replay); a pick uses
  1 draw, a shuffle of n elements n − 1 draws, a weighted choice 1 draw (scaled to the weight sum). The existing
  rejection-sampled integer method stays as it is.
- Q: What is the saved generator state's format? → A: A small value with `version` (1) and the four state words as
  16-digit lower-case hexadecimal strings, encodable as JSON; restoring refuses another version, a wrong word count
  or length, non-hex text and the all-zero state. It is an addition beside the generator; equality and output of
  existing generators are unchanged.
- Q: Which shader functions get a CPU twin? → A: The integer hash `vc_pcg` and the three value hashes `vc_hash11`,
  `vc_hash21`, `vc_hash22` that build on it (float inputs taken by bit pattern exactly as the shader does);
  goldens come from evaluating the shader source by hand-checked arithmetic, and a simulator test renders 64
  inputs with `vc_pcg` into an integer target and compares exactly.
- Q: Where does the determinism and conventions document live? → A: `docs/architecture/determinism.md`, cited from
  the package README and Auto-Creator.md section 13; a script checks that every backticked public name in it exists
  in the API baseline.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Independent named random streams from one seed (Priority: P1)

An experience author derives separate random streams (for example "layout", "particles", "audio", or level number
7) from one scene seed, so that adding draws to one stream never changes another and every stream replays from the
seed alone.

**Why this priority**: every game and creative experience needs more than one stream; hand-made seed offsets
collide and are not documented.

**Independent Test**: derive streams by label and by index from fixed seeds and compare their first values with
committed golden values; change the draws of one stream and check that the others are unchanged.

**Acceptance Scenarios**:

1. **Given** seed 42 and the label "layout", **When** a sub-seed is derived twice, **Then** both are identical and
   equal a committed golden value.
2. **Given** one seed, **When** sub-seeds are derived for labels "a" and "b" and for indexes 0 and 1, **Then** all
   four differ from each other and from the seed.
3. **Given** a stream derived from a label, **When** another stream draws any number of values, **Then** the first
   stream's values do not change.

---

### User Story 2 - Random algorithms whose results never change (Priority: P1)

An author shuffles a deck, picks a tile or makes a weighted choice and gets the same result from the same seed in
every build, so saved levels, golden tests and scenario digests stay valid after a toolchain update.

**Why this priority**: the standard library does not promise that its shuffle and random-element algorithms stay
the same; a change would silently break every committed digest.

**Independent Test**: shuffle, pick and weighted choice with fixed seeds compared with committed golden results.

**Acceptance Scenarios**:

1. **Given** seed 7 and the list 0…9, **When** it is shuffled, **Then** the order equals a committed golden order and
   is a permutation of the input.
2. **Given** weights (1, 0, 3), **When** 1,000 weighted choices are made from a fixed seed, **Then** index 1 is never
   chosen and the counts equal committed golden counts.
3. **Given** an empty list, all-zero weights, a negative weight or a non-finite weight, **When** a pick or weighted
   choice is asked for, **Then** it reports the problem instead of returning a value.

---

### User Story 3 - Save and resume randomness mid-session (Priority: P2)

A player leaves a game mid-level; when the game resumes, the random stream continues exactly where it stopped.

**Why this priority**: games that save mid-level would otherwise have to replay every step from the seed.

**Independent Test**: draw some values, save the generator state, draw more, restore, and compare; feed corrupted
and newer-version saved states.

**Acceptance Scenarios**:

1. **Given** a generator after 100 draws, **When** its state is saved and restored into a new generator, **Then** the
   next 100 values of both are identical.
2. **Given** a saved state that is corrupted, all zero, or has a newer format version, **When** it is restored,
   **Then** restoring fails with a reason and no generator is created.

---

### User Story 4 - The CPU computes the same hash as the shader (Priority: P2)

An author checks on the CPU what a shader will compute from its integer hash, so a CPU reference image or a parity
test agrees with the GPU.

**Why this priority**: GPU noise and CPU game logic that must agree (for example a hit test on a procedural field)
need the same function on both sides.

**Independent Test**: CPU hash of fixed inputs compared with golden values; the same inputs computed by the shader
on the simulator compared with the CPU values.

**Acceptance Scenarios**:

1. **Given** integer inputs 0, 1, 12345 and the largest 32-bit value, **When** the CPU hash runs, **Then** it equals
   committed golden values that follow the shader source.
2. **Given** a small grid of inputs rendered by the shader hash on the simulator, **When** the read-back values are
   compared with the CPU twin, **Then** every value matches exactly.

---

### User Story 5 - Numbers that never poison the state (Priority: P2)

An author makes physics or layout values finite, keeps angles in one range, wraps positions on a torus and quantizes
values before they enter a digest, with one shared, tested set of helpers.

**Why this priority**: a single NaN or −0 in saved state breaks digests and replays; today each experience
re-implements these guards.

**Independent Test**: helpers on edge values (NaN, ±infinity, −0, huge values, negative moduli, exact boundaries)
compared with expected results.

**Acceptance Scenarios**:

1. **Given** NaN or an infinity, **When** it is made finite with a fallback, **Then** the fallback is returned.
2. **Given** an angle of any finite size, **When** it is normalized, **Then** the result lies in [−π, π) and differs
   from the input by a whole number of turns.
3. **Given** a value and a positive modulus, **When** it is wrapped, **Then** the result lies in [0, modulus), also for
   negative values.
4. **Given** a value and a grid step, **When** it is quantized, **Then** the result is an integer count of steps,
   −0 becomes 0, and a non-finite value or a value beyond the integer range is reported.

---

### User Story 6 - One page of determinism rules and conventions (Priority: P3)

An author reads one document that states which operations replay identically, which do not, and the coordinate,
unit and handedness conventions of VisualCore.

**Why this priority**: the rules exist only as code comments; a new author can break determinism without knowing.

**Independent Test**: the document exists, names each existing clock, generator and helper by its real name, and a
check confirms every name it cites exists in the public interface.

**Acceptance Scenarios**:

1. **Given** the document, **When** the documented-name check runs, **Then** every cited public name exists.
2. **Given** the document, **When** an author reads it, **Then** it states integer-only game rules, the step policy,
   the trust boundary of transcendental functions (identical on the reference host and simulators, observed on
   devices in the device campaign), matrix order, handedness, y-axis direction and depth range.

### Edge Cases

- **Existing outputs:** the golden sequences of the existing generators and every committed scenario digest of A01–A04
  stay byte-identical; new helpers are additions only.
- **Empty or degenerate input:** empty lists, a single element, all-zero weights, a zero or negative modulus or grid
  step are reported, never answered with a value or a crash.
- **Non-finite numbers:** NaN and infinities never reach a digest; helpers either replace them with a stated fallback
  or report them.
- **Corrupted or newer-version data:** a saved generator state that is short, all zero, or of a newer version is
  refused with a reason.
- **Very large counts:** derivation by index accepts the full 64-bit range; shuffle of a large list runs in time
  proportional to its length.
- **Lifecycle and memory pressure:** all helpers are value computations without shared state; interruption,
  backgrounding or memory pressure cannot leave a half-updated stream. Not applicable beyond that.
- **Cancellation:** not applicable (no long-running work).

## Requirements *(mandatory)*

### Functional Requirements

**Existing behavior (reuse)**
- **FR-R02F03-001**: The existing fixed-step clock, runner, time-step policy and scene clock MUST keep their behavior;
  the feature documents them and adds no second clock.
- **FR-R02F03-002**: The existing generators' output sequences and every committed scenario digest MUST stay
  byte-identical (checked by the existing golden tests and by verifying A01–A04 scenarios).

**Seed derivation (story 1)**
- **FR-R02F03-010**: A sub-seed MUST be derivable from a seed and a text label, and from a seed and an unsigned
  integer index, deterministically and with committed golden values, by the SplitMix64-finalizer rule of the
  clarifications (integer arithmetic only).
- **FR-R02F03-011**: Derivations from different labels or indexes of one seed MUST give different sub-seeds for every
  golden case, and derivation MUST be chainable (a sub-seed can be derived again).
- **FR-R02F03-012**: A generator MUST be creatable directly from a seed and a label or index.
- **FR-R02F03-013**: Existing hand-made seed offsets (A04's `seedStep`) MUST stay unchanged, because their scenario
  digests are committed; the determinism document points new code to the derivation.

**Owned algorithms (story 2)**
- **FR-R02F03-020**: Shuffle (in place and copying) MUST use an algorithm owned by the project, give a permutation,
  and match committed golden results.
- **FR-R02F03-021**: Picking one element MUST be uniform over the elements and report an empty input.
- **FR-R02F03-022**: Weighted choice MUST return an index with probability proportional to its weight, never choose a
  zero-weight index, and report empty, all-zero, negative or non-finite weights.
- **FR-R02F03-023**: These algorithms MUST consume exactly one draw per random index (pick 1, shuffle n − 1,
  weighted choice 1), mapping a draw to [0, n) by the high half of the 128-bit product.

**Saved generator state (story 3)**
- **FR-R02F03-030**: A generator's full state MUST be exportable and restorable so that the restored generator
  continues the identical sequence.
- **FR-R02F03-031**: The saved state MUST carry a format version (1) and the four state words as 16-digit lower-case
  hexadecimal strings, encodable as JSON; any other version MUST be refused.
- **FR-R02F03-032**: An all-zero, short or otherwise invalid saved state MUST be refused with a reason.
- **FR-R02F03-033**: Adding the saved state MUST NOT change existing equality or output of generators.

**Shader hash twin (story 4)**
- **FR-R02F03-040**: CPU functions MUST compute exactly what the shader's `vc_pcg`, `vc_hash11`, `vc_hash21` and
  `vc_hash22` compute (float inputs by bit pattern), with golden values derived from the shader source.
- **FR-R02F03-041**: A simulator test MUST render a grid of at least 64 inputs with the shader hash and match the CPU
  twin exactly.

**Numeric hygiene (story 5)**
- **FR-R02F03-050**: A helper MUST return a finite value or a stated fallback for any input.
- **FR-R02F03-051**: Angle normalization MUST map every finite angle into [−π, π).
- **FR-R02F03-052**: Wrapping MUST map every finite value into [0, modulus) for a positive finite modulus and report
  any other modulus.
- **FR-R02F03-053**: Quantization MUST turn a finite value and a positive grid step into an integer count, write −0
  as 0, and report non-finite values, a non-positive step and values outside the integer range.
- **FR-R02F03-054**: Every helper MUST be pure (same input, same output) and documented.

**Documentation (story 6)**
- **FR-R02F03-060**: One determinism document, `docs/architecture/determinism.md`, MUST state the step policy, integer-only rules for game logic, the
  trust boundary of transcendental and floating-point functions, the stream-derivation rules and the replay format.
- **FR-R02F03-061**: The same document MUST state the transform conventions: column-major storage, counter-clockwise
  y-up 2D, right-handed 3D with −z forward, OpenGL depth range, units, and how UIKit's y-down coordinates convert.
- **FR-R02F03-062**: Every public name the document cites MUST exist in the public interface (checked).

**Common**
- **FR-R02F03-070**: Every new public declaration MUST have `///` documentation, appear in the API baseline, live in
  the pure package (randomness and time in the simulation module, numeric helpers in the math module), and be
  covered by host tests.
- **FR-R02F03-071**: Every new helper MUST name a consumer (an existing experience or a planned shared feature) in
  the plan.
- **FR-R02F03-072**: Tests MUST be short: golden vectors and counts of at most 10,000 draws.

### Key Entities

- **Sub-seed derivation:** (seed, label or index) → seed; chainable.
- **Saved generator state:** format version and the four state words.
- **Weighted choice input:** a list of non-negative finite weights with a positive sum.
- **Determinism document:** rules, conventions and the names they cite.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F03-001**: 100% of existing generator golden tests and A01–A04 scenario digests are unchanged after the feature.
- **SC-R02F03-002**: Derived sub-seeds match 100% of committed golden values, and all derived seeds in the golden set
  are pairwise different.
- **SC-R02F03-003**: Shuffle, pick and weighted choice match 100% of committed golden results; a zero-weight index is
  chosen 0 times in 1,000 draws; 4 of 4 invalid weight inputs are reported.
- **SC-R02F03-004**: A restored generator continues identically for 100 of 100 draws; 3 of 3 invalid saved states are
  refused.
- **SC-R02F03-005**: The CPU hash matches 100% of shader-derived golden values and 64 of 64 simulator read-back values.
- **SC-R02F03-006**: The hygiene helpers give the expected result for 100% of the listed edge values.
- **SC-R02F03-007**: The determinism document cites only existing public names (0 unknown names).
- **SC-R02F03-008**: Every new test finishes in under 1 second on the reference host.

## Assumptions

- Transcendental functions and floating-point results are identical on the reference host and the simulators
  (same architecture and system libraries); identity on devices is observed in the device campaign, and game rules
  that must replay across devices use integers.
- The public-domain designs of SplitMix64, xoshiro256**, the PCG integer hash and Fisher–Yates carry no license
  obligation; the implementations are written in the repository.
- R02-F02 and UA-F02 are pass in the migration ledger.
