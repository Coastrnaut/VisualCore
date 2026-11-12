# Feature Specification: UA-F03 — Experience host and session lifecycle

**Feature Branch**: `189-ua-f03-experience-host` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F03 (migration ledger) · ID namespace FR-U03-###, SC-U03-###, T-U03-###

**Input**: User description: the UA-F03 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/189-ua-f03-experience-host`; requirement ids FR-U03-###, success criteria
  SC-U03-###, task ids T-U03-###.
- **Names from the brief:** ExperienceSession and ExperienceHostView in the module VisualCoreExperienceHost; the
  existing RenderHost, ResourceRegistry, ResourceBudget, FrameScheduler, ResourceLedger, QualityPolicy and
  DeviceConditions; the tool `scripts/check_app_isolation.py`. Names of new types are proposals until
  `/speckit-plan` confirms them against the code. Other modules are not named here.
- **Who the users are:** a person who opens an experience from the app, uses it, leaves it and opens another; and
  the later features that sit on the session: the app shell (UA-F04) shows the host view, persistence (UA-F05)
  receives the snapshots, quality (UA-F06) supplies budgets and tiers, the verification runner (UA-F09) reads the
  session's record.
- **Out of scope:** the launcher and settings interface (UA-F04) and purchases (UA-F08). Where an experience may
  be opened at all (entitlement) is decided before the session is asked to open it.
- **Device-only item:** memory and thermal behavior of long sessions on D1, D2 and D3, after
  ImplementationLock-100. **Owner-only items:** none.
- **What exists today:** the experience contract of UA-F02 (a shell that joins a pure core with a presenter and
  answers every call in every lifecycle state), a render host that observes background, foreground and memory
  warnings and can recreate its context, a resource registry with a budget and counts of live and leaked objects.
  Nothing yet owns a render host on behalf of an experience, enforces one experience at a time, or shows what
  happened when an experience fails.

## Clarifications

### Session 2026-11-12

Questions asked and answered under the owner's standing delegation (recommended option first).

- Q: Does the opener hand the session a finished experience or a way to make one? → A: A way to make one
  (recommended): the open request carries a factory. The session builds the experience for each open and for each
  Retry, so a retry never reuses an object that failed, and a closed experience is released completely.
- Q: What happens when a second open arrives while the first is still opening? → A: The newest request wins
  (recommended). Opens are handled one after another; a request that is overtaken before it runs ends with the
  result "superseded" and changes nothing; an opening in progress is cancelled and closed before the next starts.
- Q: Who tells the session about scene phases and memory warnings? → A: The host view passes the scene phase on;
  the session itself listens for the system's memory warning (recommended). The render host keeps its own
  reactions (it pauses in the background and trims its pools); the session adds the experience-level reaction.
  Tests call the same two entry points directly.
- Q: What does "still over its budget" mean, given that the registry refuses any allocation beyond the budget?
  → A: A separate memory-pressure limit in bytes, by default half of the budget's total (recommended). After
  shedding, live bytes above that limit close the experience with the message.
- Q: Where do the session's decisions live? → A: In a pure, host-testable value in the pure package: the state
  table, the order of a close and the pressure rule (recommended). The main-actor session carries them out.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Opening an experience always ends in something usable (Priority: P1) 🎯

A person opens an experience. The session prepares it, creates the render host with the experience's resource
budget, activates it and shows the first frame with the experience's controls. If anything fails on the way, the
person sees what happened with Retry and Back, and the rest of the app keeps working.

**Why this priority**: it is the path every one of the 100 experiences takes; E-01 and E-11 of the common contract.

**Independent Test**: on both simulator runtimes, open the sample experience through the session and read the
picture; open variants that fail in preparation, in setup and in drawing and read the session's state.

**Acceptance Scenarios**:

1. **Given** no experience is open, **When** the sample is opened, **Then** the session passes through preparing
   to running, the first frame shows the picture of the sample's state, the controls are present, and the time of
   each stage (prepare, host creation, activation, first frame) is recorded.
2. **Given** an experience whose preparation fails, whose setup fails or whose drawing fails, **When** it is
   opened, **Then** the session is in the failed state, the failure (stable code and text) is in the session's
   diagnostics, the host view shows the failure with Retry and Back, and no GPU object of the session is live.
3. **Given** a failed session, **When** Retry is chosen and the cause is gone, **Then** the experience opens with
   the same seed and runs. **When** Back is chosen, **Then** the session is idle and another experience can be
   opened.
4. **Given** a preparation that takes longer than its time limit, **When** the limit passes, **Then** the session
   fails with the timeout code and offers Retry and Back.

---

### User Story 2 - Only one experience is ever open, and leaving leaves nothing behind (Priority: P1)

A person leaves an experience or opens another one. The session stops the clock, hands out a final snapshot,
deactivates the experience, destroys the render host and checks that no GPU object is live or leaked. Only then
is the next experience prepared.

**Why this priority**: E-09 of the common contract and Principle III. One hundred experiences share one app; a
leak in any of them would end up in all of them.

**Independent Test**: open and close the sample 50 times on both simulator runtimes and read the counts after
every close; open a second experience while the first is running and read the order of events.

**Acceptance Scenarios**:

1. **Given** a running experience, **When** it is closed, **Then** the events are, in this order: clock stopped,
   final snapshot handed out, deactivation begun, render host destroyed, zero live and zero leaked objects
   confirmed, session idle.
2. **Given** a running experience A, **When** experience B is opened, **Then** A is closed completely (the order
   above) before B's preparation starts, and at no moment are two render hosts alive.
3. **Given** 50 open and close cycles of the sample, **When** the counts are read after each close, **Then** live
   and leaked objects are 0 every time, and the live bytes while running do not grow from cycle to cycle.
4. **Given** an experience that keeps a GPU object after teardown, **When** it is closed, **Then** the session
   records a leak failure with its own code, still releases the render host, and stays able to open another
   experience.

---

### User Story 3 - Leaving while it is still loading is safe (Priority: P1)

A person opens an experience and leaves before it is ready, or opens another one at once. The preparation is
cancelled, nothing of it arrives later, and the session is ready for the next request.

**Why this priority**: E-10. People change their mind faster than levels generate.

**Independent Test**: open the slow sample and close it after 50 ms; open the slow sample and open the normal
sample at once; count what reaches the presenter afterwards.

**Acceptance Scenarios**:

1. **Given** an experience that is still preparing, **When** it is closed, **Then** the session is idle within
   1 second, no render host was created, and no setup, draw or action reaches the experience afterwards.
2. **Given** an experience that is still preparing, **When** another experience is opened, **Then** the first
   preparation is cancelled and the second experience opens and runs.
3. **Given** a preparation result that arrives after the close, **When** it arrives, **Then** it is discarded and
   changes nothing.

---

### User Story 4 - The experience pauses with the app and comes back where it was (Priority: P1)

The app goes to the background, is interrupted, or returns. In the background and during an interruption the
session suspends the experience: the clock stops and the render host is paused. Back in the foreground it resumes
without running the missed time. A snapshot is handed out at suspension, so a termination in the background loses
nothing.

**Why this priority**: E-08 and E-05. It is what makes termination safe.

**Independent Test**: on the simulators, send the session the phases background, inactive and active in several
orders and compare step counts and digests.

**Acceptance Scenarios**:

1. **Given** a running experience, **When** the app goes to the background, **Then** the experience is suspended,
   the render host is paused, a snapshot is handed out, and no step runs until the app is active again.
2. **Given** a suspended experience, **When** the app becomes active after 10 seconds, **Then** the experience
   runs again and the step count has grown by 0 for the time away.
3. **Given** a running experience, **When** the app becomes inactive (an interruption) and active again, **Then**
   the experience was suspended in between and the digest is the same before and after.
4. **Given** an experience that is preparing or failed when the app goes to the background, **When** the app
   returns, **Then** the session is in a consistent state: the preparation continued or was completed, or the
   failure is still shown; nothing was activated while the app was in the background.

---

### User Story 5 - Memory pressure and a lost context do not lose the person's state (Priority: P2)

Under a memory warning the session asks the experience to shed its caches. If the session is then still over its
resource budget, it closes the experience with a message instead of letting the system end the app. When the
render context is lost and recreated, the picture is rebuilt from the state and the state itself is untouched.

**Why this priority**: acceptance items 6 and 7; rare events, but the ones that lose work when they are not
handled.

**Independent Test**: on the simulators, send a memory warning to a session within and to one over its budget;
force a context recreation and compare digest and picture.

**Acceptance Scenarios**:

1. **Given** a running experience below its memory-pressure limit, **When** a memory warning arrives, **Then** caches are shed,
   the digest is unchanged and the experience keeps running.
2. **Given** a running experience that is above its memory-pressure limit after shedding, **When** a memory
   warning arrives,
   **Then** a snapshot is handed out, the experience is closed with zero live and leaked objects, and the host
   view shows a message with Back.
3. **Given** a running experience, **When** the render context is recreated, **Then** the next frame shows the
   same picture, the digest is unchanged, and no object of the old context generation is in use.
4. **Given** a context that cannot be recreated, **When** recovery fails, **Then** the session fails with a typed
   reason and offers Retry and Back.

---

### User Story 6 - No experience and no app code talks to the graphics context directly (Priority: P2)

The isolation check of the repository covers experience modules and the app: their sources contain no direct GL
or EGL call and no import of the low-level graphics shims. Only the framework's rendering module does.

**Why this priority**: acceptance item 8 and Principle I. With one hundred experiences the rule must be checked
by a tool, not by reading.

**Independent Test**: run the check on a clean tree, then on scratch copies with one forbidden import and one
forbidden call.

**Acceptance Scenarios**:

1. **Given** the repository as it is, **When** the check runs for experience modules, **Then** it passes and
   reports how many files it read.
2. **Given** a scratch experience source with a low-level graphics import or call, **When** the check runs,
   **Then** it fails and names file and line.
3. **Given** a path that holds no experience sources yet, **When** the check runs, **Then** it passes and says
   that nothing was found, without pretending to have checked something.

---

### Edge Cases

- **Open while closing.** A request to open during a close waits for the close to end; nothing is prepared while
  a render host of the previous experience still exists.
- **Close when idle, close twice.** Nothing happens; it is not an error.
- **Retry while preparing.** Refused; one preparation at a time.
- **Failure while closing.** A leak or a teardown error is recorded; the session still becomes idle and usable.
- **Background during preparation.** The preparation may finish; activation waits until the app is active.
- **Background during a failure or a message.** The view stays; nothing is activated.
- **Memory warning while suspended or preparing.** Caches are shed where an experience exists; no activation.
- **Snapshot refused at open.** When a stored snapshot is passed in and the experience refuses it (damaged,
  foreign, newer), the experience opens fresh and the refusal is recorded with its code; nothing crashes.
- **Zero-size or missing surface.** Without a surface no frame is drawn and the first-frame time is not recorded;
  the session stays in running and draws as soon as a surface exists.
- **Rapid open and close.** 20 opens and closes within a second leave the session idle with zero objects.

## Requirements *(mandatory)*

### Functional Requirements

**Session and its states**

- **FR-U03-001**: A session MUST be in exactly one of these states: idle, preparing, running, suspended, failed,
  message, closing. It MUST start idle. The legal changes MUST be exactly these 17: idle → preparing; preparing →
  running, suspended, failed or closing; running → suspended, failed or closing; suspended → running, failed or
  closing; failed → preparing or idle; message → idle or preparing; closing → idle or message. Any other change
  MUST be refused and counted.
- **FR-U03-002**: At most one experience MUST be open in a session, and the app MUST use one session. At no
  moment MUST two render hosts created by the session be alive.
- **FR-U03-003**: An open request MUST carry a factory for the experience, the seed, an optional snapshot, the
  resource budget, the memory-pressure limit and the preparation time limit. The session MUST build a new
  experience from the factory for every open and every Retry. Opening MUST follow this order: prepare the
  experience (with the given seed and time limit),
  restore the given snapshot when one is passed in, create the render host with the experience's resource budget,
  activate, draw the first frame. Each stage's duration MUST be recorded.
- **FR-U03-004**: Opening while another experience is open or preparing MUST first close that experience
  completely (FR-U03-010) and only then start the new preparation. Open requests MUST be handled one after
  another and the newest MUST win: a request that is overtaken before it runs MUST end with the result
  "superseded" and change nothing.
- **FR-U03-005**: A stored snapshot that the experience refuses at open MUST NOT stop the opening: the experience
  opens fresh and the refusal is recorded with its code.
- **FR-U03-006**: The session MUST publish its state, the open experience's id, the stage timings and its
  diagnostics so that an interface can observe them.

**Closing and resource proof**

- **FR-U03-010**: Closing a running or suspended experience MUST follow this order: stop the clock; hand out a
  final snapshot; begin the experience's deactivation; destroy the render host; read the registry's counts; end
  the deactivation; become idle.
- **FR-U03-011**: After a close the registry of the destroyed host MUST report 0 live and 0 leaked objects. A
  live or leaked object MUST be recorded as a failure with the leak code, MUST NOT prevent the session from
  becoming idle, and MUST NOT prevent the next open.
- **FR-U03-012**: The render host MUST be created by the session and by nothing else, with the resource budget
  the opener gives for the experience, and MUST be destroyed by the session on every path that leaves the
  experience (close, failure followed by Back, memory closure, replacement by another experience).
- **FR-U03-013**: Closing an idle session, or closing twice, MUST do nothing and MUST NOT be an error.

**Failure isolation**

- **FR-U03-020**: An error in preparation, in scene setup or in drawing MUST put the session into the failed
  state, MUST destroy the render host if one exists, MUST record the failure (stable code and text) in the
  session's diagnostics, and MUST leave the app able to open any experience.
- **FR-U03-021**: The host view MUST show a failed session as a failure view with the failure's text and two
  native controls, Retry and Back. Retry MUST open the same experience again with the same seed; Back MUST make
  the session idle.
- **FR-U03-022**: Preparation MUST have a time limit (10 seconds unless the opener gives another); exceeding it
  MUST be a failure with the timeout code.
- **FR-U03-023**: A failure while closing MUST be recorded and MUST still end in idle.

**Cancellation**

- **FR-U03-030**: Closing, or opening another experience, while an experience is preparing MUST cancel that
  preparation. The session MUST be idle, or preparing the new experience, within 1 second in the test
  environments.
- **FR-U03-031**: A preparation result that arrives after its cancellation MUST be discarded. No setup, draw,
  update or action MUST reach an experience after its close began, except teardown.
- **FR-U03-032**: No render host MUST be created for an experience whose preparation was cancelled.

**Scene phases**

- **FR-U03-040**: The session MUST take the app's scene phase (active, inactive, background) as input. In
  background and in inactive a running experience MUST be suspended and the render host paused; in active a
  suspended experience MUST resume.
- **FR-U03-041**: Resuming MUST NOT run steps for the time away.
- **FR-U03-042**: At every suspension the session MUST hand out a snapshot of the experience, before the
  suspension returns.
- **FR-U03-043**: An experience MUST NOT be activated while the phase is not active: a preparation that finishes
  in the background leads to a suspended experience that runs when the app is active.
- **FR-U03-044**: The session MUST receive the scene phase from its host view (or a test) and MUST listen itself
  for the system's memory warning, with exactly one observer that is removed when the session is released. It MUST
  NOT replace the render host's own reactions and MUST drive the host through the host's own pause and resume.

**Memory pressure and context loss**

- **FR-U03-050**: On a memory warning the session MUST ask the open experience to shed its caches. Shedding MUST
  NOT change the digest.
- **FR-U03-051**: When, after shedding, the live bytes of the session's registry exceed the memory-pressure limit
  of the open request (by default half of the budget's total), the session
  MUST hand out a snapshot, close the experience (FR-U03-010) and enter the message state with a text that says
  the experience was closed to free memory. The host view MUST show the message with Back.
- **FR-U03-052**: After a context recreation the experience MUST draw again from its state, the digest MUST be
  unchanged, and the session MUST record the recreation.
- **FR-U03-053**: When the render host reports an error that is not recoverable, the session MUST fail with a
  typed reason (FR-U03-020).

**Host view**

- **FR-U03-060**: ExperienceHostView MUST show, for a running or suspended session, the experience's canvas
  through the existing surface view together with the experience's native controls; for preparing a progress
  indication with a Cancel control; for failed the failure view; for message the message view; for idle nothing
  of an experience.
- **FR-U03-061**: The canvas MUST carry the experience's state description as its accessibility label, and every
  control of the host view MUST be a native control with a label and an identifier that starts with the
  experience's accessibility prefix (or `session.` for the session's own controls).
- **FR-U03-062**: The host view MUST layout its controls so that they stay reachable at the largest Dynamic Type
  size on the smallest supported screen in the simulators, and MUST use no color as the only carrier of meaning.
- **FR-U03-063**: Texts of the host view MUST come from the app's string resources of the module, not from
  literals scattered in code, so that they can be localized later.

**Snapshots**

- **FR-U03-070**: The session MUST hand snapshots to a sink that the opener supplies (the persistence feature
  later), at suspension, at close and before a memory closure. Without a sink the snapshots are dropped. A sink
  that throws, or a snapshot that the experience cannot produce, MUST be recorded with its code and MUST NOT stop
  the suspension or the close.
- **FR-U03-071**: The session MUST NOT write files and MUST NOT read stored data itself.

**Diagnostics**

- **FR-U03-080**: The session MUST expose one diagnostics value: its state, the open experience's diagnostics,
  the stage timings of the last open, the GPU counts after the last close, the number of opens, closes, failures,
  cancelled preparations, memory closures and context recreations, and the last failure.
- **FR-U03-081**: The diagnostics MUST be a value that can be written into an evidence file, and reading it MUST
  have no side effect.

**Isolation check**

- **FR-U03-090**: `scripts/check_app_isolation.py` MUST accept experience module directories in addition to app
  directories, MUST fail with file and line for a low-level graphics import or a direct EGL or GL call in their
  sources, and MUST say plainly, with exit code 0, when a given directory holds no source file or does not exist
  yet. An option MUST turn "no sources" into a failure for gates that must find sources.
- **FR-U03-091**: Test sources MUST stay outside the check by one stated rule (they may use the low-level calls to
  read pixels), and the tool's output MUST state how many test files it left out.

**Framework obligations and boundaries**

- **FR-U03-100**: The session and the host view MUST live in VisualCoreExperienceHost and MUST run on the main
  actor. Pure decisions (the session's state table, the order of a close, the memory-pressure rule) MUST be one
  host-testable value in the pure package, and the session MUST carry out what that value decides.
- **FR-U03-101**: The feature MUST NOT change the public API of the experience contract of UA-F02 except by
  additions, and MUST NOT change the render host's behavior.
- **FR-U03-102**: Every public symbol MUST have documentation, the API baseline MUST be updated, both packages'
  tests MUST pass on the host and on the iOS 27.x and iOS 26.5 simulators, and the ProjectM reference regression
  MUST pass.
- **FR-U03-103**: The feature MUST NOT add an app target, a launcher, settings, purchase code, network use,
  advertising, analytics or tracking code, and MUST NOT change the reference submodule or the vendored tree.
- **FR-U03-104**: Memory and thermal behavior of long sessions MUST be listed as a device task for D1, D2 and D3
  and MUST NOT be claimed from simulator runs.

### Key Entities

- **Session**: state, open experience, render host, budget, phase, sink, counters.
- **Open request**: experience factory, seed, optional snapshot, resource budget, memory-pressure limit, time
  limit. **Open result**: running, failed, cancelled or superseded.
- **Stage timings**: prepare, host creation, activation, first frame.
- **Session failure**: code, text, stage in which it happened.
- **Session diagnostics**: the readable record of FR-U03-080.
- **Snapshot sink**: where snapshots go; supplied by the opener.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U03-001**: In 100% of the tested sequences of opens (including opens during preparing, running, failed and
  closing) at most one render host is alive at any moment, and the previous experience's close is complete
  before the next preparation starts.
- **SC-U03-002**: 50 open and close cycles of the sample on each of the two simulator runtimes end with 0 live
  and 0 leaked objects after every close, and the live bytes while running are equal in cycle 1 and cycle 50.
- **SC-U03-003**: Each of the three failure kinds (preparation, setup, drawing) and the timeout ends in the failed
  state with its code in the diagnostics, 0 live objects, a failure view with Retry and Back, and a successful
  open of the sample afterwards, in 100% of the runs.
- **SC-U03-004**: A close during preparation makes the session idle within 1 second, creates 0 render hosts and
  lets 0 setup, draw or action calls reach the presenter, in 20 of 20 repetitions.
- **SC-U03-005**: For the phase sequences background → active and inactive → active, each after 10 seconds away,
  the step count grows by 0 for the time away and the digest is equal before and after; a snapshot is handed out
  at every suspension.
- **SC-U03-006**: A memory warning below the memory-pressure limit changes neither digest nor state; a memory
  warning above it ends in the message state with 0 live objects and one snapshot handed out.
- **SC-U03-007**: After a forced context recreation the centre pixel shows the same colour as before within 2 of
  255 and the digest is equal, on both simulator runtimes.
- **SC-U03-008**: The isolation check passes on the repository, fails on 2 of 2 scratch violations with file and
  line, and reports "no sources" for an empty directory.
- **SC-U03-009**: 100% of the new public symbols are documented, the API baseline check passes with no removed
  line, package tests pass on the host and on both simulator runtimes, and the reference regression passes 7 of 7.
- **SC-U03-010**: Laid out in a window of 320 by 568 points at the largest accessibility text size on both
  simulator runtimes, the failure view, the message view and the preparing view are not wider than the window,
  their content is reachable by scrolling, and their controls have a minimum size of 44 by 44 points. Taps on
  these controls by an interface test belong to the app's tests of UA-F04.

## Assumptions

- The app has one session. Which experience may be opened (entitlement, availability) is decided by the caller
  before it asks the session; the session does not consult the catalog or the store.
- The resource budget of an experience comes from its quality profile (UA-F06). Until then the opener passes a
  budget; the default is the render host's own default budget.
- Storing snapshots and restoring them at launch is UA-F05; the session only hands snapshots to a sink and
  accepts one at open.
- "Interruptions are honored" means the scene phase inactive: calls, the app switcher, system sheets. Audio
  session interruptions belong to the audio experiences and their features.
- The session reuses the render host's own handling of background, foreground, memory warnings (pool trimming)
  and surface changes; it adds the experience-level reactions on top.
- Timings are simulator or host measurements and are recorded for comparison, never as device performance. The
  device task of this feature covers memory and thermal behavior of long sessions.
- Texts are English in this feature; the string resources make later localization possible.
- No advertising, analytics, tracking or network code is involved.

## Absorbed source requirements

R02-F04 "GPU resource ownership and pipeline lifetime" (session-level rules) and R02-F25 "Shared native iOS shell
and evidence-friendly UI" (session part), archive round 2.

| Source requirement | Decision | Where and why |
|---|---|---|
| R02-F04: per-context residency of GPU objects | adopted | FR-U03-012, FR-U03-052: every object belongs to the session's render host and its context generation |
| R02-F04: main loop ownership (one owner of frames and of the context thread) | adopted | FR-U03-002, FR-U03-044, FR-U03-100: one session, one render host, main actor |
| R02-F04: destruction ordering | adopted | FR-U03-010, FR-U03-011: fixed close order ending with a count of live and leaked objects |
| R02-F04: resource caches | adapted | FR-U03-050, FR-U03-051: the registry's caches and pools already exist; the session adds shedding and the budget rule |
| R02-F04: immutable resource descriptors | superseded | The registry's creation calls already take value descriptions; no session rule is needed |
| R02-F04: stale context leaves no invalid GL reference; live count returns to baseline after closing | adopted | FR-U03-052, FR-U03-011, SC-U03-002, SC-U03-007 |
| R02-F25: transparent render hosting in native interface | adopted | FR-U03-060: the host view shows the existing surface view with native controls |
| R02-F25: pause and resume | adopted | FR-U03-040 to FR-U03-043 |
| R02-F25: progress | adapted | FR-U03-060: a progress indication while preparing; level progress belongs to the games |
| R02-F25: accessibility | adopted | FR-U03-061, FR-U03-062, SC-U03-010 |
| R02-F25: SwiftUI menus | superseded | Menus, launcher and settings are UA-F04 (out of scope here) |
| R02-F25: evidence-friendly interface (stable identifiers, readable state) | adopted | FR-U03-061, FR-U03-080, FR-U03-081 |
| Both: failure reports carry feature id, app id, seed, tick, tier and reason code | adapted | FR-U03-080: the experience's diagnostics of UA-F02 inside the session's diagnostics; the experience id replaces the app id |
| Both: price range and "no IAP" of the round 2 text | superseded | ADR-0009 and Principle XII; nothing of it concerns this feature |

## Traceability

| Source | Requirement |
|---|---|
| Acceptance 1 (one session active; the first is deactivated before the new one prepares) | FR-U03-001–004, US2, SC-U03-001 |
| Acceptance 2 (zero live and leaked after deactivation; 50 cycles on both runtimes) | FR-U03-010–013, US2, SC-U03-002 |
| Acceptance 3 (failure view with Retry and Back; app stays usable; failure in diagnostics) | FR-U03-020–023, FR-U03-080, FR-U03-081, US1, SC-U03-003 |
| Acceptance 4 (leaving during prepare cancels; no callback after deactivation) | FR-U03-030–032, US3, SC-U03-004 |
| Acceptance 5 (background suspends, foreground resumes without catching up, interruptions) | FR-U03-040–044, US4, SC-U03-005 |
| Acceptance 6 (memory warning sheds caches; over budget deactivates with a message) | FR-U03-050, FR-U03-051, US5, SC-U03-006 |
| Acceptance 7 (forced context recreation keeps the digest) | FR-U03-052, FR-U03-053, US5, SC-U03-007 |
| Acceptance 8 (no direct GL or EGL calls; isolation check extended) | FR-U03-090, FR-U03-091, US6, SC-U03-008 |
| Scope: render host creation with a budget, host view | FR-U03-003, FR-U03-012, FR-U03-060–063, SC-U03-010 |
| Scope: snapshots handed out, opening with a snapshot | FR-U03-005, FR-U03-006, FR-U03-070, FR-U03-071 |
| Out of scope: launcher, settings, purchases | FR-U03-103 |
| Device-only: memory and thermal behavior of long sessions | FR-U03-104 |
| Auto-Creator.md sections 11.4 (session, orders), 11.5 (threads), 11.6 (failure, cancellation, phases, memory) | FR-U03-002, FR-U03-003, FR-U03-010, FR-U03-100, FR-U03-020, FR-U03-030, FR-U03-040, FR-U03-050 |
| ADR-0009 D-05 (one session at a time, budgeted registry, zero live resources, recoverable failure view) | FR-U03-002, FR-U03-011, FR-U03-012, FR-U03-021 |
| Constitution I, III, IV, VII, IX | FR-U03-090, FR-U03-010, FR-U03-100, FR-U03-061, FR-U03-062, FR-U03-005 |
| Framework obligations | FR-U03-101, FR-U03-102, SC-U03-009 |
| R02-F04, R02-F25 | section "Absorbed source requirements" |
