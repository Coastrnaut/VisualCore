# Feature Specification: UA-F02 — ExperienceKit: the experience contract

**Feature Branch**: `188-ua-f02-experience-sdk` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F02 (migration ledger) · ID namespace FR-U02-###, SC-U02-###, T-U02-###

**Input**: User description: the UA-F02 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/188-ua-f02-experience-sdk`; requirement ids FR-U02-###, success criteria
  SC-U02-###, task ids T-U02-###.
- **Names from the brief:** the pure module VisualCoreExperience (it exists since UA-F01) and a new module
  VisualCoreExperienceHost in `Packages/VisualCoreRendering`; the existing surfaces RenderScene, RenderHost,
  RenderSurface, FixedStepRunner, PlaybackState, DocumentStore, MigrationChain and RenderLifecycle; the helper
  ExperienceConformance. Names of new types are proposals until `/speckit-plan` confirms them against the code.
  Other modules are not named here.
- **Who the users are:** the authors of the 100 launch experiences and the later features that run them. The
  session host (UA-F03) drives an experience through this contract, the persistence feature (UA-F05) stores its
  snapshots, the quality feature (UA-F06) sets its tier, the verification runner (UA-F09) reads its diagnostics and
  uses its automation hooks. A person using the app meets the result later: every experience opens, pauses, saves,
  restores, resets and closes in the same way.
- **Out of scope:** the session host (UA-F03: one session at a time, ownership of the render host and its budget,
  entitlement, stage timings, the failure view) and any real experience.
- **Device-only and owner-only items:** none.
- **What exists today:** a render host with its own lifecycle and a resource registry that counts live and leaked
  GPU objects; a scene contract; a fixed-step clock and runner; a play and pause value; a document store with a
  versioned envelope and a migration chain; a quality policy; an automation module that compiles only under
  `DEBUG` or `VISUALCORE_AUTOMATION`. No common contract ties them together for an experience: each of the four
  existing apps wires them by hand.

## Clarifications

### Session 2026-11-12

Questions asked and answered under the owner's standing delegation (recommended option first).

- Q: Is an experience one object, or a pure core with a separate part that owns the picture? → A: Two parts
  (recommended). A pure core holds the domain state, preparation, update, actions, snapshot and digest, has no
  user-interface or graphics dependency and can be handed between threads. A main-actor shell owns the scene, the
  controls and the GPU objects and reads the core. Reason: the conformance helper must run on the Mac host, where
  no render host exists (section 11.3), and CPU-heavy preparation may run off the main actor (section 11.5). The
  sketch of section 11.3 is illustrative; it showed one main-actor protocol.
- Q: How large is the state digest and how is it computed? → A: 256 bits, SHA-256 over a canonical typed
  encoding, printed as 64 lower-case hexadecimal digits (recommended). Reason: digests are compared across one
  hundred experiences, ten thousand levels and three platforms, and the level artifacts of Rounds 3 and 4 already
  name SHA-256; the existing 64-bit checksum of the fixed-step simulation stays as it is for its own purpose.
- Q: In what form is the snapshot payload held, given that the existing migration chain works on JSON objects?
  → A: A JSON object, encoded deterministically (sorted keys), carried in an envelope that also holds the digest
  of the state at capture (recommended). 64-bit values (the seed) are written as text so that no JSON reader
  rounds them. The checksum is SHA-256 of the encoded payload. The envelope has its own format number, separate
  from the schema version of the experience.
- Q: On which thread does preparation run and how does cancellation end it? → A: The core's preparation is a pure
  asynchronous function that may run off the main actor; it checks for cancellation at bounded intervals; a
  result that arrives after cancellation, after deactivation began or after a newer preparation started is
  discarded (recommended). The caller sets a time limit; exceeding it is a failure with its own code. Everything
  that touches the graphics context stays on the main actor.
- Q: Where do the automation hooks live and how is their absence proven? → A: Inside the two modules of this
  feature, in code that compiles only under `DEBUG` or `VISUALCORE_AUTOMATION`; absence is proven by listing the
  symbols of a release build without the flag (recommended). The existing automation module is not changed; the
  verification runner (UA-F09) connects the two later.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An experience can only be driven in a legal order (Priority: P1) 🎯

The author of an experience, and the session host that runs it, rely on one lifecycle: registered, preparing,
ready, active, suspended, deactivating, inactive and failed. The lifecycle is a pure value. It accepts the legal
transitions, refuses every other one, counts each refusal and keeps a bounded history, so a wrong call order is
visible as a number and never as undefined behavior.

**Why this priority**: every other part of the contract is defined per state. Without a single reducer, one
hundred experiences would each decide for themselves what "suspended" means.

**Independent Test**: on the host, attempt every ordered pair of the eight states and compare the result with the
transition table of this specification; attempt every operation in every state and compare with the operation
table.

**Acceptance Scenarios**:

1. **Given** a new lifecycle, **When** it is driven registered → preparing → ready → active → suspended → active →
   deactivating → inactive, **Then** every transition is accepted, the rejected count is 0 and the history lists
   the seven transitions in order.
2. **Given** a lifecycle in any state, **When** a transition that the table does not list is attempted, **Then**
   the state is unchanged, the rejected count grows by one and the attempt is in the history as rejected.
3. **Given** a lifecycle in any state other than failed, **When** it fails with an error, **Then** the state is
   failed and the error is the last error; **When** it then prepares again, **Then** the state is preparing.
4. **Given** an inactive experience, **When** it is prepared again, **Then** the lifecycle accepts it (re-entry).
5. **Given** an experience in a state where an operation is not legal (for example an action while suspended),
   **When** the operation is called, **Then** it is refused with a typed reason that names the operation and the
   state, the experience's own code is not called, the state digest is unchanged and the refusal is counted.

---

### User Story 2 - The same seed always gives the same experience (Priority: P1)

An author prepares an experience from a seed and gets the same state every time, on the Mac host and on both
simulator runtimes. The domain state advances only in fixed steps, so the result does not depend on how fast
frames arrive. A fixed-size state digest makes "the same state" a value that tests and evidence can compare.

**Why this priority**: determinism is what makes levels certifiable, replays honest and saved work restorable. It
is requirement E-04 of the common experience contract.

**Independent Test**: prepare the sample experience twice for each of 256 seeds and compare digests; compare eight
of them with committed values on the host and on both simulators; feed the same simulated time in four different
frame patterns and compare step counts and digests.

**Acceptance Scenarios**:

1. **Given** one seed, **When** the experience is prepared twice, **Then** both digests are equal.
2. **Given** a list of seeds with committed digests, **When** the experience is prepared on the host, on the iOS
   27.x simulator and on the iOS 26.5 simulator, **Then** each digest equals the committed value.
3. **Given** a prepared and activated experience, **When** two seconds of time arrive as 60 frames, as 120 frames,
   as 240 frames and as irregular frames, **Then** the number of steps and the digest are the same in all four runs.
4. **Given** a frame that is longer than the per-frame step limit allows, **When** it arrives, **Then** at most
   the limit of steps run, the remaining time is counted as dropped and no later frame makes up for it.
5. **Given** a frame time that is negative or not a finite number, **When** it arrives, **Then** no step runs and
   the frame is counted as invalid.
6. **Given** a suspended experience, **When** ten seconds pass and it resumes, **Then** no step runs for the time
   it was suspended.
7. **Given** an experience whose preparation is cancelled, **When** the cancellation is observed, **Then** the
   preparation ends with a cancellation result, the experience becomes inactive and no update, draw or action
   reaches it afterwards.

---

### User Story 3 - Work is captured, brought back and reset exactly (Priority: P1)

An author asks the experience for a snapshot, later restores it and gets the same state digest. Reset gives the
state of a fresh preparation with the same seed. A snapshot is a versioned envelope: an older one is migrated, and
a damaged, foreign, oversized or newer one is refused with a typed reason while the running state stays as it was.

**Why this priority**: E-05 and E-06 of the common contract rest on it, and the persistence feature stores exactly
this envelope.

**Independent Test**: take snapshots of the sample experience at one hundred different points, restore each into a
fresh instance and compare digests; restore a committed snapshot of schema version 1 into the sample at version 2;
feed one damaged fixture per refusal reason.

**Acceptance Scenarios**:

1. **Given** an experience that has run steps and accepted actions, **When** a snapshot is taken and restored
   into another instance of the same experience, **Then** digest, seed and step index are equal.
2. **Given** an experience that has changed, **When** it is reset, **Then** its digest equals that of a fresh
   preparation with the same seed and its step index is 0.
3. **Given** a snapshot written by an older schema version, **When** it is restored, **Then** it is migrated step
   by step to the current version and the restored digest equals the committed expected digest.
4. **Given** a snapshot of a newer schema version, of another experience, with a damaged payload, with a payload
   whose checksum does not match, or larger than the size limit, **When** it is restored, **Then** the matching
   typed reason is returned and the running digest is unchanged.
5. **Given** a snapshot, **When** it is encoded, decoded and encoded again, **Then** both encodings are the same
   bytes.

---

### User Story 4 - Every input is accepted or refused with a reason (Priority: P1)

Touches and control changes reach an experience as normalized actions: a control it declared, a bounded list of
finite numbers and the step at which the action applies. The experience turns an action into its own domain
action and answers accepted or rejected with a typed reason. A rejected action changes nothing.

**Why this priority**: E-03 of the common contract. Tests, replays and the verification runner speak to all one
hundred experiences through this one door.

**Independent Test**: send the sample experience a table of valid actions and a table of invalid ones (unknown
control, too many values, a value that is not finite, a value out of range, an action its rules do not allow now)
and compare result and digest for each row.

**Acceptance Scenarios**:

1. **Given** an active experience, **When** a valid action arrives, **Then** it is accepted and the domain state
   changes in the documented way.
2. **Given** an active experience, **When** an action names a control the experience did not declare, carries
   more values than the limit, carries a value that is not finite or out of the declared range, or is not allowed
   by the rules in the current state, **Then** it is rejected with the matching typed reason and the digest is
   unchanged.
3. **Given** a touch position in a view of any size, **When** it is normalized, **Then** the result lies between
   0 and 1 on both axes, and a position outside the view or a view without area gives a refusal instead of a value.
4. **Given** a recorded list of actions with their steps, **When** it is replayed on a fresh instance with the
   same seed, **Then** the final digest equals that of the original run.

---

### User Story 5 - The picture comes from the real renderer and owns nothing that matters (Priority: P2)

An experience draws through the existing scene contract on the existing render host. Drawing reads the state and
never changes it. GPU objects are a cache: they are created on activation, rebuilt after a context loss and all
released on deactivation. No value read back from the GPU decides an outcome.

**Why this priority**: E-02, E-09 and Principle XIII. It is second only because the pure parts above can be
proven without a simulator, and this part cannot.

**Independent Test**: on both simulator runtimes, run the sample experience on a real render host: activate, draw
frames, compare the digest before and after drawing, recreate the context, deactivate and read the resource
counts.

**Acceptance Scenarios**:

1. **Given** an active sample experience on a render host, **When** 120 frames are drawn without steps or actions,
   **Then** the digest is unchanged and the centre pixel shows the colour that the state prescribes.
2. **Given** an active experience, **When** the render context is lost and recreated, **Then** the experience
   draws again, the digest is unchanged and no object of the old context generation is used.
3. **Given** an experience that was active, **When** it is deactivated, **Then** the live GPU resource count of
   the host is 0 and the leaked count is 0.
4. **Given** an experience on any quality tier, **When** the tier is changed to each other declared tier,
   **Then** the digest is unchanged.
5. **Given** an experience, **When** a memory warning asks it to shed caches, **Then** the digest is unchanged and
   the next frame is drawn correctly.

---

### User Story 6 - The state of an experience can be read and scripted (Priority: P2)

A tester, the verification runner and a failure report read one diagnostics value: lifecycle state, seed, step
index, quality tier, live GPU resource counts, last error and digest, together with the experience id. Scenario
hooks let automation drive an experience; they exist only in builds made for testing.

**Why this priority**: evidence for one hundred integration gates is collected through these values.

**Independent Test**: read the diagnostics of the sample experience in every lifecycle state on the host and on a
simulator; build the new module for release with and without the automation flag and list its symbols.

**Acceptance Scenarios**:

1. **Given** an experience in any lifecycle state, **When** its diagnostics are read, **Then** all listed items
   are present, and items that do not exist yet (for example the digest before preparation) are reported as
   absent, never as a made-up value.
2. **Given** an experience that failed, **When** its diagnostics are read, **Then** the last error carries a
   stable code and a text, and it stays readable until the next successful preparation.
3. **Given** a release build without the automation flag, **When** the symbols of the new modules are listed,
   **Then** no automation hook is among them.
4. **Given** a build with the automation flag, **When** a scenario script (seed, steps and actions) is run through
   the hooks, **Then** the result reports the final digest and the per-action results.

---

### User Story 7 - Any experience proves the contract with one call (Priority: P2)

An author adds one test that hands the experience to ExperienceConformance. The helper runs the common checks and
answers with a report that names every failed check. A sample experience that exists only for tests passes all of
them on the host and on both simulator runtimes, and deliberately broken variants fail the matching check.

**Why this priority**: the helper is how the contract is enforced one hundred times without one hundred
hand-written copies of the same tests.

**Independent Test**: run the helper on the sample (all checks pass) and on seven broken variants, one per check
(exactly the matching check fails).

**Acceptance Scenarios**:

1. **Given** the sample experience, **When** the helper runs, **Then** the report lists every check as passed.
2. **Given** a variant whose preparation depends on something other than the seed, **When** the helper runs,
   **Then** the seed-determinism check fails and names the seed.
3. **Given** variants that lose a field in the snapshot, that reset to a different state, that change state on a
   rejected action, that change state on a tier change, that change state when caches are shed, or whose result
   depends on something other than seed and actions during a run, **When** the helper runs, **Then** exactly the
   matching check fails in each case.

---

### Edge Cases

- **Failure during preparation.** The experience becomes failed, the error is kept as last error, no partial state
  is visible (digest absent) and a new preparation is legal.
- **Failure while drawing or updating.** The experience becomes failed; deactivation is still legal and releases
  every GPU resource.
- **Cancellation.** Leaving during preparation cancels it. A preparation that completes after it was cancelled is
  discarded. Nothing reaches the experience after deactivation.
- **Preparation that does not end.** Preparation has a time limit that the caller sets; exceeding it is a failure
  with its own code. A result that arrives late is discarded.
- **Lifecycle interruption.** Suspension stops the clock; resume does not catch up. A suspension request in a
  state other than active is refused and counted; the caller decides what to do next.
- **Memory pressure.** Shedding caches never changes the digest. What is shed is rebuilt on demand.
- **Context loss.** GPU objects are rebuilt from CPU state; a handle of an old context generation is never used
  and never stored in a snapshot.
- **Damaged, foreign, oversized or newer snapshot.** Refused with a typed reason; the running state is unchanged
  and reset stays available.
- **Empty and extreme values.** Seeds 0 and the largest 64-bit value prepare normally. An action without values
  is valid when the control takes none. Step indices do not overflow within 10 years of continuous running at
  the shortest step.
- **Repeated calls.** Deactivating twice, activating twice or preparing while preparing is refused and counted;
  nothing is released twice.
- **A second lifecycle.** The render host keeps its own lifecycle (surface and context). The experience lifecycle
  sits above it and never replaces it.

## Requirements *(mandatory)*

### Functional Requirements

**Lifecycle**

- **FR-U02-001**: The experience lifecycle MUST be a pure value with exactly eight states: registered, preparing,
  ready, active, suspended, deactivating, inactive and failed. A new lifecycle starts in registered.
- **FR-U02-002**: The legal transitions MUST be exactly these 20: registered → preparing; preparing → ready;
  preparing → deactivating (cancellation); ready → active; ready → deactivating; active → suspended; active →
  deactivating; suspended → active; suspended → deactivating; deactivating → inactive; inactive → preparing
  (re-entry); failed → preparing (retry); failed → deactivating (leave); and → failed from each of the seven other
  states.
- **FR-U02-003**: Every other transition, including a transition from a state to itself, MUST be rejected: the
  state stays, a rejected counter grows by one and the attempt is recorded as rejected.
- **FR-U02-004**: The lifecycle MUST keep a bounded history of transition attempts (accepted and rejected, at most
  64 unless the caller sets another limit of at least 1, oldest dropped first) and the count of rejected attempts
  since creation.
- **FR-U02-005**: Entering failed MUST store the error as last error. The last error MUST stay readable until the
  next preparation succeeds.
- **FR-U02-006**: Each operation of the contract MUST be legal only in these states: prepare in registered,
  inactive and failed; activate in ready; update and action in active; snapshot, restore, reset, tier change and
  cache shedding in ready, active and suspended; suspend in active; resume in suspended; deactivate in preparing,
  ready, active, suspended and failed. An operation called in another state MUST be refused with a typed reason
  that names the operation and the state, MUST NOT call the experience's own code, MUST leave the digest unchanged
  and MUST be counted.
- **FR-U02-007**: No update, draw, action or other callback MUST reach an experience after its deactivation has
  begun, except the deactivation itself.

**Preparation, seed and digest**

- **FR-U02-010**: Preparation MUST take a 64-bit seed and MUST build the whole domain state from it and from data
  shipped with the experience, with no use of the clock, of random sources other than the seed, of the network or
  of stored user data.
- **FR-U02-011**: Preparation MUST be asynchronous and cancellable. A cancelled preparation MUST end with a
  cancellation result, MUST leave no visible state and MUST lead to inactive.
- **FR-U02-012**: A failed preparation MUST lead to failed with a typed error; no partial state MUST be visible.
- **FR-U02-013**: Every prepared experience MUST offer a state digest of 256 bits, the SHA-256 of a canonical
  typed encoding of its domain state, printed as 64 lower-case hexadecimal digits. Equal states MUST give equal digests in every process, on the Mac host and on both
  simulator runtimes. The digest MUST NOT depend on wall-clock time, memory addresses, the iteration order of
  unordered collections, the quality tier, or anything read from the GPU.
- **FR-U02-014**: The same seed MUST give the same digest after every preparation.
- **FR-U02-015**: The contract MUST offer one shared way to build a digest from integers, booleans, text, byte
  sequences and finite floating-point numbers, and that way MUST refuse a number that is not finite. The encoding
  MUST mark the type and the length of every field, so that two different sequences of fields never give the same
  bytes.
- **FR-U02-016**: The core's preparation MAY run off the main actor. It MUST check for cancellation between its
  units of work, often enough that a cancelled preparation ends within 1 second in the test environments. A preparation result that arrives after cancellation, after deactivation began or after a newer
  preparation started MUST be discarded.
- **FR-U02-017**: The caller MUST be able to set a time limit for preparation. Exceeding it MUST be a failure with
  its own stable code.

**Fixed-step update**

- **FR-U02-020**: The domain state MUST advance only in fixed steps of a length the experience declares, between
  1/240 s and 1/30 s; without a declaration the length is 1/120 s, and a declared length outside the range MUST be
  brought to the nearest end of the range. An update MUST receive the step index and MUST make no graphics call.
- **FR-U02-021**: The steps run for a given amount of simulated time MUST NOT depend on how that time is divided
  into frames, as long as no frame exceeds the per-frame step limit.
- **FR-U02-022**: The number of steps per frame MUST be limited (at most 8). Time beyond the limit MUST be counted
  as dropped and MUST NOT be made up later.
- **FR-U02-023**: A frame time that is negative or not finite MUST run no step and MUST be counted.
- **FR-U02-024**: Suspension MUST stop stepping. Resuming MUST NOT run steps for the time spent suspended.
- **FR-U02-025**: The step index MUST be a 64-bit count that starts at 0 after preparation and after reset, grows by
  one per step and is restored by a snapshot.

**Input**

- **FR-U02-030**: Input MUST reach an experience as a normalized action: the id of a control the experience
  declared, at most 8 finite numbers and the step index at which it applies. Positions MUST be normalized to the
  range 0 to 1 on both axes.
- **FR-U02-031**: An experience MUST declare its controls: for each a stable id, the number of values it takes
  and their ranges.
- **FR-U02-032**: The answer to an action MUST be accepted, or rejected with a typed reason. The reasons MUST
  include at least: unknown control, wrong number of values, value not finite, value out of range, not allowed in
  the current lifecycle state, a step index that is not the current one, and refused by the experience's rules
  with an experience-defined code.
- **FR-U02-033**: A rejected action MUST leave the digest unchanged.
- **FR-U02-034**: The checks for unknown control, number of values, finiteness and range MUST be made by the
  contract before the experience's own code sees the action.
- **FR-U02-035**: Converting a touch position into normalized coordinates MUST be a pure function of position and
  view size that refuses positions outside the view and views without area.
- **FR-U02-036**: Replaying a recorded list of accepted actions at their step indices on a fresh instance with
  the same seed MUST give the same digest as the original run.

**Snapshot, restore and reset**

- **FR-U02-040**: A snapshot MUST be a pure, versioned envelope holding: the envelope format number, the
  experience id, the schema version of the experience, the seed, the step index, the digest of the state at
  capture, the payload and the SHA-256 checksum of the encoded payload. The payload MUST be a JSON object. It MUST
  NOT hold a GPU handle, a memory address or a time of day.
- **FR-U02-041**: Restoring a snapshot taken from the same experience at the same schema version MUST reproduce
  digest, seed and step index.
- **FR-U02-042**: A snapshot of an older schema version MUST be migrated step by step with the existing
  MigrationChain. A missing migration step MUST be a typed refusal.
- **FR-U02-043**: Restore MUST refuse, with a distinct typed reason each: a snapshot of another experience, an
  unknown envelope format, a newer schema version, a payload that does not decode, a checksum mismatch, and an
  encoded snapshot larger than 1,048,576 bytes. When a snapshot of the current schema version restores to a state
  whose digest differs from the digest in the envelope, that MUST be a typed refusal too. Together with the
  missing migration step of FR-U02-042 these are eight typed reasons.
- **FR-U02-044**: A refused restore MUST leave the running state exactly as it was (same digest, same step
  index).
- **FR-U02-045**: Reset MUST give the state of a fresh preparation with the current seed: equal digest, step
  index 0. After a restore the current seed is the seed of the restored snapshot.
- **FR-U02-046**: The encoded form of a snapshot MUST be deterministic (keys in sorted order): encoding the same
  snapshot twice gives the same bytes, and a decoded snapshot encodes to the bytes it was decoded from. 64-bit
  values MUST be written as text so that they survive every JSON reader exactly.
- **FR-U02-047**: The envelope MUST be storable by the existing DocumentStore without a second envelope format
  for the same purpose.

**Drawing and GPU ownership**

- **FR-U02-050**: An experience MUST draw through the existing RenderScene contract on the existing RenderHost.
  This feature MUST NOT add a renderer, a second graphics context or a second frame scheduler.
- **FR-U02-051**: Drawing MUST read the state and MUST NOT change the digest. No value read back from the GPU
  MUST decide an outcome or enter the digest.
- **FR-U02-052**: GPU objects MUST be created through the host's resource registry at activation or in scene
  setup, MUST be rebuilt from CPU state after a context loss, and MUST all be released when deactivation ends: the
  live count and the leaked count of the host are then 0. An object that is still live or leaked at that moment
  MUST be reported as a typed failure, and the lifecycle MUST become failed instead of inactive.
- **FR-U02-053**: Everything that touches the graphics context MUST run on the main actor. CPU work of
  preparation MAY run elsewhere when it is pure and hands finished values to the main actor.
- **FR-U02-054**: An experience MUST accept a quality tier out of the tiers it declares (at least one; tier 0 is
  the best). A tier it did not declare MUST be refused with a typed reason. Changing the tier MUST NOT change the
  digest.
- **FR-U02-055**: An experience MUST offer cache shedding for memory pressure. Shedding MUST NOT change the
  digest, and whatever was shed MUST be rebuilt on demand.
- **FR-U02-056**: An experience MUST offer its native controls and a text that describes its current state for
  assistive technology, so that a host can show the controls and label the canvas. Control and canvas identifiers
  MUST start with the accessibility prefix that the catalog derives from the experience id.

**Diagnostics and automation**

- **FR-U02-060**: Every experience MUST expose one diagnostics value with: experience id, lifecycle state, seed,
  step index, quality tier, live GPU resource counts (objects, bytes, leaked), last error (stable code and text)
  and digest, and the counters of this contract: rejected transitions, refused operations, accepted and rejected
  actions, dropped time and invalid frames. An item that does not exist yet MUST be reported as absent.
- **FR-U02-061**: Diagnostics MUST be readable in every lifecycle state without side effects, and MUST be a value
  that can be written into an evidence file.
- **FR-U02-062**: Scenario hooks for automation (run a script of seed, steps and actions; read the results) MUST
  compile only under `DEBUG` or `VISUALCORE_AUTOMATION`. A release build without the flag MUST contain none of
  them, proven by listing the symbols of that build. The existing automation module MUST stay unchanged.
- **FR-U02-063**: Errors of the contract MUST be typed, each with a stable code that does not change between
  releases.

**Conformance and the sample experience**

- **FR-U02-070**: A reusable helper, ExperienceConformance, MUST run these checks for the core of any experience on the host
  and report each as passed or failed with the reason: seed determinism, snapshot round trip, reset equivalence,
  rejection leaves the digest unchanged, tier change leaves the digest unchanged, cache shedding leaves the digest
  unchanged, replay of recorded actions reproduces the digest.
- **FR-U02-071**: The helper MUST NOT depend on a test framework, so that any test target and any tool can call
  it, and MUST be bounded: the caller sets the seeds, steps and actions it uses.
- **FR-U02-072**: A sample experience used only by tests MUST exercise the whole contract: on the host the pure
  parts, and on the iOS 27.x and iOS 26.5 simulators the parts that need a render host. The sample MUST NOT be
  part of any shipped product: only test targets may depend on the module that holds it, and the dependency check
  of the repository MUST fail otherwise.
- **FR-U02-073**: For each check of the helper there MUST be a deliberately broken variant of the sample that
  fails exactly that check.

**Framework obligations and boundaries**

- **FR-U02-080**: An experience MUST consist of two parts. The core (domain state, preparation, update, actions,
  snapshot, digest) and the other pure parts (lifecycle, digest builder, snapshot envelope, action types,
  diagnostics, conformance) MUST live in VisualCoreExperience, MUST stay free of user-interface and graphics
  dependencies and MUST be usable from any thread. The shell (scene, controls, GPU objects) and everything else
  that needs a render host or SwiftUI MUST live in VisualCoreExperienceHost in `Packages/VisualCoreRendering` and
  MUST run on the main actor.
- **FR-U02-081**: The contract MUST adapt the existing surfaces named in the brief and MUST NOT duplicate them:
  the fixed-step clock and runner, the scene contract and render host, the document envelope and store, the
  migration chain and the render lifecycle keep their behavior and their public API.
- **FR-U02-082**: Every public symbol MUST have documentation, the API baseline MUST be updated, and both modules
  MUST have package tests: VisualCoreExperience on the host and on both simulator runtimes, VisualCoreExperienceHost
  on both simulator runtimes.
- **FR-U02-083**: The ProjectM reference regression MUST be rerun after the framework change and MUST pass.
- **FR-U02-084**: This feature MUST NOT add an app target, the session host, a real experience, purchase code,
  network use, advertising, analytics or tracking code, and MUST NOT change the reference submodule or the
  vendored tree. No type of the reference engine MUST appear in the new public API.
- **FR-U02-085**: Code paths that read a snapshot or an action MUST NOT trap on any input: no forced unwrap, no
  unchecked index and no fatal error on data.

### Key Entities

- **Experience lifecycle**: state, last error, rejected count and bounded history; the transition table and the
  operation table.
- **State digest**: a fixed-size value of the domain state, printable as text, comparable across platforms.
- **Experience action**: control id, values, step index. **Action result**: accepted or rejected with a reason.
- **Control declaration**: id, number of values, ranges.
- **Experience core and shell**: the pure part that holds the domain state, and the main-actor part that owns
  scene, controls and GPU objects.
- **Experience snapshot**: envelope format, experience id, schema version, seed, step index, digest at capture,
  payload (a JSON object), checksum.
- **Experience diagnostics**: the readable state of an experience at one moment.
- **Scenario script and result** (automation builds only): seed, steps, actions; final digest and per-action
  results.
- **Conformance report**: one entry per check with pass or fail and the reason.
- **Sample experience**: a small deterministic experience with one control, two schema versions and a drawable
  state, plus its broken variants; tests only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U02-001**: All 64 ordered pairs of lifecycle states are tested: exactly 20 are accepted and 44 are
  rejected, and each rejection leaves the state unchanged and raises the rejected count by exactly one. All 12
  operations are tested in all 8 states and are legal in exactly the states listed.
- **SC-U02-002**: For 256 seeds, two preparations of the sample give equal digests in 100% of the cases; for 8
  seeds the digest equals a committed value on the host and on both simulator runtimes.
- **SC-U02-003**: At 100 different points of a run, snapshot and restore reproduce digest, seed and step index in
  100% of the cases; reset equals a fresh preparation in 100% of 32 tried seeds; a committed version-1 snapshot
  restores to its committed digest; each of the eight typed refusal reasons is produced by its fixture, and the
  running digest is unchanged in every refusal.
- **SC-U02-004**: Every rejection reason is produced by at least one row of the action table, and the digest is
  unchanged after 100% of the rejected actions; a replay of 200 recorded actions reproduces the digest.
- **SC-U02-005**: Two seconds of simulated time fed as 60, 120, 240 and irregular frames give the same step count
  and the same digest in all four runs; a suspension of ten seconds adds 0 steps.
- **SC-U02-006**: Diagnostics contain all listed items in each of the 8 lifecycle states; on both simulator
  runtimes the live GPU resource count is above 0 while the sample is active and exactly 0, with 0 leaked, after
  deactivation, also after a context recreation.
- **SC-U02-007**: A release build of the new modules without the automation flag contains 0 automation hook
  symbols; a build with the flag runs a scenario script of at least 100 steps and 10 actions and reports the
  expected digest.
- **SC-U02-008**: The sample passes all 7 conformance checks on the host; each of the 7 broken variants fails
  exactly its own check; the whole conformance run for the sample takes less than 10 seconds on the development
  Mac.
- **SC-U02-009**: 100% of the new public symbols are documented, the API baseline check passes, the package tests
  pass on the host and on both simulator runtimes, and the reference regression passes 7 of 7 steps.
- **SC-U02-010**: A cancelled preparation of the sample ends within 1 second of the cancellation, leaves the
  lifecycle inactive, and 0 updates, draws or actions reach the sample afterwards.

## Assumptions

- The users of this feature are authors and later features; there is no screen in this feature. Accessibility
  requirements therefore reduce to what the contract must offer (controls, a state description and stable
  identifiers); the audit of real screens belongs to the features that show them.
- The session host (UA-F03) decides when to call each operation: which seed to use, when to restore a stored
  snapshot, what to do when the app goes to the background during preparation, and how to show a failure. This
  feature gives it a contract that answers every call in every state.
- Storing snapshots on disk, the storage layout and automatic saving are UA-F05. This feature only guarantees
  that the envelope fits the existing document store.
- Choosing a tier from thermal state and Low Power Mode is the existing quality policy and UA-F06. This feature
  only requires that an experience accepts a tier and that the tier never changes the digest.
- The shared actions and the control declaration cover what the common contract needs. Gesture recognition
  beyond turning a position into normalized coordinates (orbit, pinch, stepper alternatives) is built by the
  experiences and their shared features on top of it.
- Solver certification, level schemas, uniqueness and fairness stay in R02-F23. Only the lifecycle and digest
  parts of that feature are absorbed here.
- Timings are host measurements on the development Mac or simulator results, never device performance.
- No advertising, analytics, tracking or network code is involved, and nothing here touches a physical device.

## Absorbed source requirements

R02-F23 "Puzzle contract, seed generation and solver certification" (archive: round 2, feature R2-F23). Its
unique requirements and what happens to each:

| Source requirement | Decision | Where and why |
|---|---|---|
| Versioned serialization of the pure model | adopted | FR-U02-040 to FR-U02-047: one versioned envelope for every experience |
| Deterministic reference behavior; identical seed and ordered inputs give a stable digest on repeated CPU runs (test T02) | adopted | FR-U02-010, FR-U02-013, FR-U02-014, FR-U02-036 |
| Parameter validation; zero and minimal inputs never produce NaN or infinity (T03); maximum parameters are bounded (T04) | adapted | FR-U02-030 to FR-U02-034 and FR-U02-015: validation is done once by the contract for every action and digest instead of per puzzle; GPU memory bounds stay with the resource budget of the session host |
| Disposal and recreation of the context leaves no invalid GL reference (T05) | adopted | FR-U02-052, User Story 5 scenario 2 |
| Live resource count returns to the baseline after closing and reopening (T08) | adopted | FR-U02-052, SC-U02-006 |
| Critical state is exposed in human-readable native descriptions (T07) | adapted | FR-U02-056: the contract requires the description; the screens that read it are later features |
| Failure reports carry feature id, app id, seed, tick, capability tier and reason code | adapted | FR-U02-060, FR-U02-063: experience id replaces app id, because there is one app (ADR-0009) |
| No unguarded newer-OS symbol on iOS 26.5 (T09) | adopted | FR-U02-082: package tests on the iOS 26.5 simulator |
| Public API does not require the reference engine (T01) | adopted | FR-U02-084 |
| Absent optional extension follows a documented fallback (T06) | superseded | Capabilities and tiers are UA-F06; the contract only carries the tier (FR-U02-054) |
| Immutable level schemas, explicit solutions, uniqueness mode, fairness budget, solver certification | not absorbed | They stay in R02-F23, as the brief states |
| Separate price range and "no IAP" of the round 2 text | superseded | ADR-0009 and Principle XII: one app, one purchase; nothing of it concerns this feature |

## Traceability

| Source | Requirement |
|---|---|
| Acceptance 1 (pure lifecycle reducer, exhaustive tests, illegal transitions rejected and counted) | FR-U02-001–007, US1, SC-U02-001 |
| Acceptance 2 (deterministic preparation, conformance helper checks it) | FR-U02-010–017, FR-U02-070, FR-U02-071, US2, SC-U02-002, SC-U02-010 |
| Acceptance 3 (restore reproduces the digest, reset equals fresh preparation, versioned envelopes with migrations) | FR-U02-040–047, US3, SC-U02-003 |
| Acceptance 4 (normalized input, rejection leaves the digest unchanged, typed reason) | FR-U02-030–036, US4, SC-U02-004 |
| Acceptance 5 (fixed steps independent of frame rate, drawing reads immutable state, no GPU result decides) | FR-U02-020–025, FR-U02-050–052, US2, US5, SC-U02-005 |
| Acceptance 6 (diagnostics) | FR-U02-060, FR-U02-061, US6, SC-U02-006 |
| Acceptance 7 (automation hooks only under DEBUG or VISUALCORE_AUTOMATION) | FR-U02-062, US6, SC-U02-007 |
| Acceptance 8 (sample experience on host and both simulators; documented and baselined API) | FR-U02-072, FR-U02-073, FR-U02-082, US7, SC-U02-008, SC-U02-009 |
| Scope: suspend, resume, deactivate, tier, cache shedding | FR-U02-006, FR-U02-024, FR-U02-052, FR-U02-054, FR-U02-055 |
| Out of scope: session host, real experiences | FR-U02-084 |
| Auto-Creator.md section 6.1 (E-03, E-04, E-05, E-06, E-08, E-09, E-10, E-11, E-13) | FR-U02-030–036, FR-U02-010–025, FR-U02-040–047, FR-U02-045, FR-U02-024, FR-U02-052, FR-U02-011, FR-U02-016, FR-U02-012, FR-U02-054 |
| Auto-Creator.md section 11.3 (operations, states, conformance helper), 11.5 (threads), 11.6 (failure, cancellation, no traps) | FR-U02-001–007, FR-U02-070, FR-U02-053, FR-U02-011, FR-U02-012, FR-U02-063, FR-U02-085 |
| ADR-0009 D-05 (one contract that adapts the existing surfaces) | FR-U02-080, FR-U02-081 |
| Constitution II (reuse obligations), III (lifecycle and context generation), IX (bounded untrusted input), XI (identity), XIII (code-driven visuals) | FR-U02-082, FR-U02-083, FR-U02-052, FR-U02-043, FR-U02-085, FR-U02-056, FR-U02-050 |
| R02-F23 (lifecycle and digest parts) | section "Absorbed source requirements" |
