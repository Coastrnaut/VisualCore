# Feature Specification: UA-F06 — Quality profiles and performance observability

**Feature Branch**: `192-ua-f06-quality-performance` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F06 (migration ledger) · ID namespace FR-U06-###, SC-U06-###, T-U06-###

**Input**: User description: the UA-F06 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/192-ua-f06-quality-performance`; requirement ids FR-U06-###, success
  criteria SC-U06-###, task ids T-U06-###.
- **Names from the brief:** `QualityProfile` is a new name (it exists nowhere today); `QualityPolicy`,
  `DeviceConditions`, `FramePacing`, `ParticleBudget` and `RenderCostEstimate` exist in VisualCoreDiagnostics;
  `docs/performance/` exists with host and simulator baselines and no budget document. Names of other new types
  are proposals until `/speckit-plan` confirms them.
- **Who the users are:** a person whose device gets warm or runs in Low Power Mode and who expects the picture
  to stay smooth; a person who pins a quality level in the settings; the author of an experience, who must say
  in numbers what each quality level costs; and the later features that read what this one measures: the
  adoption of the first experiences (UA-F07), the verification runner and its evidence records (UA-F09) and the
  device campaign.
- **Out of scope:** tuning individual experiences. The complete evidence record, its validator and the tool that
  runs scenarios for every experience belong to UA-F09; this feature delivers the performance part of that record
  and proves it on the sample and debug experiences.
- **Device-only item:** frame pacing, memory, thermal and shader-compile measurements on D1, D2 and D3 with at
  least 200 samples for percentage criteria, after ImplementationLock-100. **Owner-only items:** none.
- **What exists today (audit of 2026-11-12):** an experience declares a number of quality levels and can be set
  to one of them without changing its state digest; the catalog can carry up to eight level names per experience
  and carries none yet; the app stores one override (automatic, or 0 to 7) and applies it after an experience
  opened; "automatic" does nothing; the session times preparation, host creation, activation and a first drawn
  (not presented) frame; shader compilation is part of host creation and is not timed on its own; nothing
  measures the launch, frame intervals or the memory footprint.

## Clarifications

### Session 2026-11-12

Answered by the lead under the owner's standing delegation; the recommended option was taken each time.

- Q: Shaders cannot be compiled in the pure preparation of an experience's state, which has no display context — at which moment must they be compiled, and how is that proven? → A: In the set-up that follows the preparation and precedes activation (Auto-Creator.md §12.2 rule 3 speaks of "preparation" in this wider sense). The set-up is timed as its own stage with the number of programs compiled; the proof is that the number of compilations does not rise once the experience is interactive.
- Q: Is the ten-minute scenario ten minutes on the wall clock or ten minutes of experience time? → A: Ten minutes of experience time: 72,000 fixed steps of 1/120 s with at least 36,000 frames really drawn, as fast as the simulator draws them, so that the run fits one command of under ten minutes. A wall-clock run of that length is part of the device task.
- Q: The complete evidence record and its tool are UA-F09's — what does this feature deliver of it? → A: The performance part as its own versioned value (version 1) with one text form, produced by the session; UA-F09 embeds it unchanged. This feature adds no verification tool; it proves the record with package tests on both simulator runtimes and with the app's tests.
- Q: Who decides the automatic level, how often, and how does it relate to the frame-rate cap that already reacts to heat? → A: The session decides, on the main thread: once when an experience opens (before its first frame) and then at most once per second while it runs, from the device conditions at that moment. The Low Power level is level 1 (the last level for an experience with one level). The existing reaction of the frame scheduler (30 frames per second under heat or Low Power Mode, three quarters of the resolution at critical heat) stays as it is and multiplies with the level's resolution share; both are named in the record.
- Q: What counts as "no unbounded growth"? → A: The first tenth of the samples is the warm-up. Graphics bytes: the largest value after the warm-up must not exceed the largest value of the warm-up. Memory footprint: the median of the last quarter of the samples minus the median of the first quarter after the warm-up must not exceed 8 MiB or 5% of that first median, whichever is larger. At least 60 samples are taken.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Each experience says in numbers what its quality levels mean (Priority: P1) 🎯

The author of an experience declares its quality levels once: a name for each level and, for each, the numbers
the experience is allowed to spend — how much of the display resolution, what share of its elements (particles,
instances), what share of its iterations and how many effect passes. Level 0 is the best. A lower level never
costs more than the one above it. Changing the level changes what is drawn, never the state of the experience.

**Why this priority**: acceptance item 1. Without declared numbers "lower quality" is a wish; with them the
shell, the tests and the device campaign all speak about the same thing.

**Independent Test**: declare a profile for the sample experience, ask it for the numbers of each level, switch
through every level while the experience runs a scripted scenario and compare the state digest with a run that
never switched.

**Acceptance Scenarios**:

1. **Given** an experience with a profile of three levels, **When** the numbers of each level are read,
   **Then** every level has a name and four budgets, and no budget of a lower level is larger than the same
   budget of the level above it.
2. **Given** a running experience, **When** its level is changed to every declared level in turn, **Then** the
   state digest after the scenario equals the digest of the same scenario without any change.
3. **Given** a profile whose number of levels differs from the number the experience's logic declares, or whose
   names differ from the catalog's names for that experience, **When** the experience is checked, **Then** the
   check fails and names the difference.
4. **Given** a profile with no level, more than eight levels, a level without a name, a budget outside its range
   or a lower level that costs more than a higher one, **When** it is created, **Then** it is refused with the
   reason.

---

### User Story 2 - Quality follows the device, and a pinned level stays pinned (Priority: P1)

With the setting on automatic, an open experience steps one level down when the device reports a serious or
critical thermal state or runs in Low Power Mode, and steps back up, one level at a time, after the device has
been calm for the calm period. A person who pins a level in the settings gets that level, whatever the device
reports. The level is in force from the first frame of an experience, not only after it opened.

**Why this priority**: acceptance item 2. A warm phone that keeps a smooth, simpler picture is the behaviour a
person notices; a pinned level that drifts would be a broken promise.

**Independent Test**: drive an open sample experience with a scripted sequence of device conditions and times
and read the level after each step; repeat with a pinned level; open an experience with a pinned level and read
the level of its first frame.

**Acceptance Scenarios**:

1. **Given** automatic quality and an experience at its best level, **When** the thermal state becomes serious,
   **Then** the level steps down by one per decision interval until the last level, never by more.
2. **Given** an experience that stepped down, **When** the device stays nominal or fair without Low Power Mode
   for the calm period, **Then** the level steps up by one, and by one more after each further calm period.
3. **Given** automatic quality, **When** Low Power Mode is on, **Then** the level is at least the Low Power level
   and does not recover while Low Power Mode stays on.
4. **Given** conditions that flip between serious and nominal faster than the calm period, **When** they are
   followed for a minute, **Then** the level never steps up.
5. **Given** a pinned level, **When** the device becomes hot or enters Low Power Mode, **Then** the level stays
   the pinned one; **When** the pinned level is not declared by the experience, **Then** its last level is used.
6. **Given** a pinned level or a device that is already hot, **When** an experience opens, **Then** its first
   frame is drawn at the level in force, not at level 0.
7. **Given** an experience that is suspended or closed, **When** conditions change, **Then** no level is changed
   and nothing is counted; after a resume the decisions start again from the current conditions.

---

### User Story 3 - Opening an experience is measured stage by stage, and shaders never compile in an interactive frame (Priority: P1)

When an experience opens, the time of each stage is recorded on its own: preparing its state, compiling its
shaders, and showing its first frame on the display. The time from the start of the app to the usable launcher
is recorded once per launch. Every shader an experience needs is compiled before its first interactive frame; a
shader that is compiled later is counted and reported as a fault.

**Why this priority**: acceptance items 3 and 5. A stutter in the first second is the most visible defect an
experience can have, and it can only be removed when it is measured apart from everything else.

**Independent Test**: open the sample experience and read the stage times; open a deliberately faulty
experience that compiles a shader in its tenth frame and read the count of late compilations.

**Acceptance Scenarios**:

1. **Given** an experience that opens successfully on a display, **When** its measurements are read, **Then**
   preparation, shader compilation and first present each have their own time, each zero or more, and the first
   present time ends at a frame that was really presented.
2. **Given** an experience that needs shaders, **When** it has become interactive, **Then** the number of shader
   compilations equals the number at the end of its set-up, for as long as the display context is not replaced.
3. **Given** an experience that compiles a shader after it became interactive, **When** its measurements are
   read, **Then** the late compilations are counted and the performance check of that experience fails.
4. **Given** a replaced display context, **When** the experience rebuilds its shaders, **Then** these
   compilations are counted as a rebuild and not as late compilations.
5. **Given** an open that fails or is cancelled before a stage ended, **When** its measurements are read,
   **Then** the stages that ended have their times and the others are absent — never zero, never an estimate.
6. **Given** a start of the app, **When** its first screen (the launcher, or the welcome on a first start) has
   become usable, **Then** one launch time is recorded
   for that start, it is not recorded again in the same process, and a first start after an installation is
   marked as such.

---

### User Story 4 - While an experience runs, its pacing, memory and graphics memory are observed and recorded (Priority: P2)

While an experience runs, the app counts how many display refreshes were met and how many were missed, and
notes the app's memory footprint and the bytes its graphics objects hold. Together with the stage times, the
quality level, the thermal state and Low Power Mode, these make one performance record that the verification of
an experience stores with its evidence.

**Why this priority**: acceptance item 3. The device campaign judges every experience by these numbers; they
must exist, mean one thing and be the same in every experience.

**Independent Test**: run the sample experience for a fixed number of frames with scripted frame times and
read the pacing counts; read the record as text and read it back.

**Acceptance Scenarios**:

1. **Given** a sequence of frame times with known late frames, **When** the pacing is read, **Then** the number
   of samples, the on-time and the missed refreshes and the median, 95th and 99th percentile interval are the
   expected values.
2. **Given** a running experience, **When** its performance record is read, **Then** it holds the launch time,
   preparation time, shader compilation time, first present time, the pacing counts, the memory footprint, the
   graphics bytes (current and peak), the quality level, the thermal state and Low Power Mode, each with its unit.
3. **Given** a record written as text, **When** it is read back, **Then** it equals the original; **When** the
   text is damaged, lacks a field or has a newer version, **Then** it is refused with a stable code and nothing
   is guessed.
4. **Given** an experience that was suspended and resumed, **When** the pacing is read, **Then** the time spent
   suspended counts neither as a missed refresh nor as a sample.
5. **Given** a value that cannot be measured where the app runs (for example the footprint when the system
   refuses it), **When** the record is read, **Then** that value is absent and the record says so.

---

### User Story 5 - Ten minutes of running do not grow memory or graphics memory (Priority: P2)

A ten-minute scenario of the sample experience on the simulator shows that neither the app's memory footprint
nor the bytes of its graphics objects keep growing.

**Why this priority**: acceptance item 6. A slow leak is invisible in a short test and fatal in a long session.

**Independent Test**: run the endurance scenario on both simulator runtimes and apply the growth rule to its
samples; run a deliberately leaking experience and see the rule fail.

**Acceptance Scenarios**:

1. **Given** the endurance scenario of the sample experience, **When** it has run for ten minutes of experience
   time with every frame drawn, **Then** the graphics bytes at the end are not above their value after the
   warm-up, and the memory footprint grew by no more than the allowed margin.
2. **Given** an experience that allocates a little more in every frame, **When** the same scenario runs,
   **Then** the growth rule fails and names the quantity that grew.
3. **Given** the endurance scenario, **When** it ends, **Then** the experience's state digest equals the digest
   of the same scenario run without rendering.

---

### User Story 6 - Budgets are written down as proposals, each with the device measurement that will confirm it (Priority: P3)

The performance budgets of the app are written in one document: each as a proposal, each with the measurement
on real devices that will confirm it. Numbers measured on a simulator are labelled as development signals and
never as results.

**Why this priority**: acceptance item 4. A target that was never measured is not a requirement, and a simulator
number presented as performance would mislead everyone who reads it.

**Independent Test**: check the document: every budget row names its confirming device measurement and sample
count, and no row or sentence presents a simulator number as a result.

**Acceptance Scenarios**:

1. **Given** the budget document, **When** it is checked, **Then** every budget is marked as a proposal and names
   the devices, the scenario and the number of samples that will confirm it.
2. **Given** a simulator number in the performance documents, **When** the documents are checked, **Then** the
   number is labelled as a simulator development signal; a document that presents one as a result fails the check.

---

### Edge Cases

- **Failure while opening**: an experience that fails in its set-up has a preparation time and no first present
  time; the record of the failed open exists, and the session's diagnostics name the stage that failed.
- **Cancellation**: leaving while an experience prepares leaves no shader or present time and no pacing sample;
  nothing is recorded as zero.
- **Backgrounding and interruptions**: a suspended experience takes no pacing sample and no quality decision;
  the launch time is not affected by a later return to the foreground.
- **Memory warning**: when the session sheds caches or closes the experience under memory pressure, the record
  keeps the peak graphics bytes and counts the event; the quality level is not changed by a memory warning.
- **Replaced display context**: shaders compiled again after the context was replaced are a rebuild, counted
  apart from the first compilation and never a late compilation; the first set-up time is not changed by it.
- **Clock anomalies**: a frame time that is not a finite number or runs backwards is counted as invalid and is
  not a sample; a non-finite time given to a quality decision keeps the level.
- **Oscillating conditions**: conditions that change faster than the decision interval change the level at most
  once per interval.
- **One level only**: an experience with one level never steps and accepts any pinned level as its only level.
- **Pinned level and a later experience**: the pinned level is global; an experience with fewer levels uses its
  last one and the record shows the level that was really applied.
- **Damaged or newer record**: a performance record that cannot be read is refused with its code; a newer
  version is refused, not read partly.
- **No display**: where frames are drawn without being presented (a test without a display), the first present
  time is absent and the record says that nothing was presented.

## Requirements *(mandatory)*

### Functional Requirements

**Quality profiles**

- **FR-U06-001**: An experience MUST be able to declare a quality profile: 1 to 8 levels, level 0 the best, each
  with a name of 1 to 40 characters that is unique in the profile.
- **FR-U06-002**: Each level MUST state four budgets: the share of the display resolution (more than 0, at most
  1), the share of elements (0 to 1), the share of iterations (0 to 1) and the number of effect passes (0 or
  more). No budget of a level MAY be larger than the same budget of the level before it.
- **FR-U06-003**: A profile that breaks FR-U06-001 or FR-U06-002 MUST be refused with a reason that names the
  level and the budget; it MUST never be repaired silently.
- **FR-U06-004**: The check that every experience passes before it is integrated MUST fail when the number of
  profile levels differs from the number of levels the experience's logic declares, or when the profile's names
  differ from the level names of that experience in the catalog.
- **FR-U06-005**: A change of level MUST NOT change the state digest of an experience; the existing check of
  this rule MUST cover every level of the profile.
- **FR-U06-006**: A profile MUST give, for a requested amount of elements or iterations and a level, the amount
  allowed at that level, so that every experience derives its numbers the same way.

**Automatic quality and the override**

- **FR-U06-010**: With the setting on automatic, the level of an open experience MUST follow the existing
  quality policy: one step down per decision interval while the thermal state is serious or critical, or while
  Low Power Mode is on and the level is above the Low Power level; one step up after each calm period without
  heat and without Low Power Mode. A decision is taken when an experience opens and then at most once per
  second while it runs. The Low Power level is level 1, or the only level of an experience with one level.
- **FR-U06-011**: The decisions MUST be taken only while an experience runs; a suspended or closed experience
  MUST neither change level nor count a decision, and a resume MUST start from the current conditions.
- **FR-U06-012**: A pinned level MUST be applied whatever the device reports; a pinned level that an experience
  does not declare MUST be replaced by its last level.
- **FR-U06-013**: The level in force (pinned, or the automatic level for the conditions at that moment) MUST be
  applied before the first frame of an experience is drawn, also after a retry.
- **FR-U06-014**: The number of steps down and steps up of a session, the level in force, and the frame-rate cap
  and resolution factor that the existing frame pacing applies under heat MUST be readable for the performance
  record. That frame pacing stays as it is: its resolution factor applies to the display surface, the level's
  resolution share is applied by the experience to what it draws, and both are recorded. Without a render host
  the cap and the factor are absent.
- **FR-U06-015**: The settings MUST say what automatic and a pinned level mean, and MUST keep the choice across
  restarts as today. The text MUST be a string resource, MUST wrap at the largest accessibility text size and
  MUST leave the settings route passing its accessibility audit. This feature MUST NOT add a per-experience
  override.

**Stage measurements**

- **FR-U06-020**: An open MUST record separately, in milliseconds: the preparation of the experience's state,
  the set-up that compiles its shaders, after the preparation and before activation (with the number of programs
  compiled) and the time from the
  start of the open to the first frame that was presented on the display.
- **FR-U06-021**: A stage that did not end MUST have no value. Zero MUST mean a measured zero.
- **FR-U06-022**: An experience is interactive from the moment its session runs after the activation. The number
  of shader compilations after that moment MUST be counted as late compilations; compilations after a replaced display context MUST be counted as a rebuild instead.
- **FR-U06-023**: The performance check of an experience MUST fail when it has one or more late compilations.
- **FR-U06-024**: The app MUST record one launch time per process: from the earliest moment the app's own code
  runs to the moment the first screen is usable (the launcher, or the welcome on a first start), with a mark for
  the first start after an installation (a start that finds no stored preferences of the app). Before that
  moment the app MUST create no rendering context. Time before the app's own code runs is
  not observable by the app and is not part of the value.

**Running measurements**

- **FR-U06-030**: While an experience runs, the display refreshes MUST be counted: samples, on-time refreshes,
  missed refreshes, and the median, 95th and 99th percentile of the interval between presented frames. A
  refresh is on time when the interval is at most one and a half refresh periods at the frame-rate cap in force;
  a longer interval misses the whole refresh periods it spans beyond the first.
- **FR-U06-031**: Time spent suspended, the first frame after a resume and frame times that are not finite or
  run backwards MUST NOT be samples; invalid frame times MUST be counted.
- **FR-U06-032**: The pacing MUST keep a bounded amount of data however long an experience runs.
- **FR-U06-033**: The memory footprint of the app and the bytes of the experience's graphics objects (current
  and peak) MUST be readable while an experience runs; a value the system does not give MUST be absent.
- **FR-U06-034**: Taking these measurements MUST NOT change what an experience computes: the state digest of a
  measured run MUST equal the digest of an unmeasured one.

**The performance record**

- **FR-U06-040**: The measurements of a session MUST form one performance record with a version (version 1), which
  the evidence record of UA-F09 embeds unchanged: launch time,
  preparation time, shader compilation time and count, late compilations, first present time, pacing counts and
  percentiles, memory footprint, graphics bytes (current and peak), quality level and whether it is pinned, steps down
  and up, the frame-rate cap and resolution factor of the frame pacing, thermal state, Low Power Mode, the number
  of display-context rebuilds and of memory-pressure events, and whether frames were presented.
- **FR-U06-041**: The record MUST have one text form that reads back to an equal record. A damaged text, a
  missing or unknown field or a newer version MUST be refused with a stable code.
- **FR-U06-042**: The record MUST carry nothing that identifies a person or a device beyond what the evidence
  record of the verification already names, and MUST never leave the device through the app.
- **FR-U06-043**: In builds made for testing the record of the open experience MUST be obtainable by a test; a
  release build MUST contain no such access and no on-screen meter.

**Endurance**

- **FR-U06-050**: An endurance scenario MUST exist for the sample experience: ten minutes of experience time
  (72,000 fixed steps) with at least 36,000 frames really drawn, sampling the memory footprint and the graphics
  bytes at 60 or more regular points. It MUST fit one command of under ten minutes on a simulator.
- **FR-U06-051**: A growth rule MUST judge the samples. The first tenth is the warm-up. The largest graphics
  bytes after the warm-up MUST NOT exceed the largest of the warm-up. The median memory footprint of the last
  quarter minus the median of the first quarter after the warm-up MUST NOT exceed 8 MiB or 5% of that first
  median, whichever is larger. The rule MUST name the quantity that fails and MUST refuse fewer than 60 samples.
- **FR-U06-052**: The rule MUST fail for an experience that grows in every frame, and the endurance run MUST end
  with the same state digest as the same scenario without rendering.

**Budgets and documents**

- **FR-U06-060**: The budgets of Auto-Creator.md section 12.5 MUST be written in `docs/performance/` as
  proposals, each with the device measurement (devices, scenario, number of samples) that will confirm it.
- **FR-U06-061**: A check MUST fail when a budget lacks its confirming measurement (devices, scenario and number
  of samples; for a budget no device measures, such as build time and app size, the tooling report that
  measures it) or when a simulator number is presented without the label of a development signal.
- **FR-U06-062**: No statement of this feature MUST present a simulator measurement as device performance.

**Boundaries and verification**

- **FR-U06-070**: Profiles, the policy that drives the level, the pacing statistics, the growth rule and the
  record MUST be pure logic that is tested without a display; reading the device and timing frames MUST live
  with the rendering code. Experience and app sources MUST still contain no direct graphics call.
- **FR-U06-071**: Every public symbol added to the framework MUST be documented, the API baseline MUST be
  updated, and the reference regression MUST pass.
- **FR-U06-072**: The feature MUST add no network use, no advertising, analytics or tracking code, and MUST use
  public system interfaces only; an interface that needs a declared reason MUST have it in the privacy manifest.
- **FR-U06-073**: The measurements on D1, D2 and D3 (pacing, memory, thermal behaviour, shader compilation,
  at least 200 samples for percentage criteria) MUST be listed as a device task that runs only after
  ImplementationLock-100.

### Key Entities

- **Quality profile**: the declared levels of one experience; for each a name and four budgets.
- **Quality level in force**: the level an open experience uses: the pinned one, or the automatic one.
- **Device conditions**: thermal state and Low Power Mode at a moment.
- **Stage times**: preparation, shader compilation, first present; and the launch time of the process.
- **Pacing summary**: samples, on-time and missed refreshes, median, 95th and 99th percentile interval, invalid
  frame times.
- **Resource sample**: memory footprint and graphics bytes at a moment of a run.
- **Performance record**: the versioned collection of all of the above for one session.
- **Budget proposal**: a target, its status as a proposal, and the device measurement that will confirm it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

All ten outcomes are verified on the host or on simulators. None of them is a statement about the performance
of a device; those belong to the device task of FR-U06-073.

- **SC-U06-001**: For the sample experience and the debug experience, 100% of the declared levels have a name
  and four budgets, and switching through every level changes 0 state digests.
- **SC-U06-002**: Of 12 invalid profiles (no level, nine levels, unnamed, duplicate name, each budget out of
  range, each budget rising), 12 are refused with the right reason.
- **SC-U06-003**: A scripted sequence of at least 20 condition changes gives exactly the expected level after
  every step in automatic mode, and the pinned level after every step in pinned mode.
- **SC-U06-004**: In 100% of opens on a display, preparation, shader compilation and first present have separate
  values; in 100% of failed or cancelled opens the stages that did not end have no value.
- **SC-U06-005**: The sample and debug experiences have 0 late shader compilations over 600 interactive frames;
  a faulty test experience with 1 late compilation is reported with exactly 1 and fails the check.
- **SC-U06-006**: For 5 scripted frame-time sequences the pacing counts and percentiles equal the expected
  values exactly, and the memory used by the pacing does not grow between 1,000 and 1,000,000 frames.
- **SC-U06-007**: A performance record with every field set reads back equal; each of at least 8 damaged or
  newer texts is refused with its code.
- **SC-U06-008**: The ten-minute endurance scenario passes the growth rule on both simulator runtimes, and a
  leaking test experience fails it in 1 of 1 runs.
- **SC-U06-009**: 100% of the budget rows name their confirming measurement (a device measurement with scenario
  and samples, or the tooling report for a budget no device measures), and the check finds 0
  simulator numbers presented as results; a scratch document with one such number fails the check.
- **SC-U06-010**: 100% of the new public framework symbols are documented, the API baseline check passes, the
  reference regression passes 7 of 7, and a release build of the app contains 0 symbols of the test access.

## Assumptions

- The three decisions of the clarification session (when shaders compile, what ten minutes means, what part of
  the evidence record this feature delivers) are binding and are not repeated here.
- Thermal state and Low Power Mode cannot be produced on a simulator; the behaviour is proven with scripted
  conditions and times, and on devices later.
- The global override of UA-F04 (automatic, or 0 to 7) stays; eight levels is also the largest profile.
- The memory footprint is the figure the system reports for the app's process; where it cannot be read the value
  is absent.
- Battery level, charging and display brightness are device-only fields of the evidence record and are not
  measured here.
- The on-screen frame meter that Auto-Creator.md section 12.6 describes for the device campaign is built with
  the verification runner (UA-F09) from the pacing counts of this feature; this feature shows no meter.

## Absorbed source requirements

| Source requirement | Decision | Where |
|---|---|---|
| R02-F32: adaptive quality | adopted | FR-U06-010 to FR-U06-014 |
| R02-F32: frame-interval histograms | adapted | FR-U06-030 to FR-U06-032: counts and three percentiles from bounded data instead of a stored histogram per frame |
| R02-F32: no false GPU statistics | adopted | FR-U06-021, FR-U06-033, FR-U06-062: only what the app can observe; absent values stay absent |
| R02-F32: a 30-minute sustained probe | adapted | FR-U06-050: ten minutes of experience time on the simulator; a long wall-clock run belongs to the device task (FR-U06-073) |
| R02-F32: prerequisites R2-F07, R2-F31; consumers: all | superseded | The gate depends on UA-F03; every experience uses the session |
| R02-F32: price "$1.99–$4.99 … no IAP" | superseded | CLAUDE.md rule 3: one USD 1.99 non-consumable |
| R03-F09, R04-F09: a D1–D3 report schema | adopted | FR-U06-040, FR-U06-041 (performance record), FR-U06-060 (confirming measurements) |
| R03-F09, R04-F09: CPU and GPU time where observable | adapted | Frame intervals and stage times are observable; GPU time is not observable on this rendering path and is not reported |
| R03-F09, R04-F09: asset-free cold and hot start baselines | adopted | FR-U06-024 (launch time, first start marked); cold and warm are separated on devices (FR-U06-073) |
| R03-F09, R04-F09: battery, memory, thermals, shader warm-up | adapted | Memory, thermal state and shader compilation here; battery is device-only |
| R03-F09, R04-F09: never claim hardware performance from a simulator | adopted | FR-U06-061, FR-U06-062 |
| R03-F09, R04-F09: existing rendering path, no fork | adopted | FR-U06-070; Principle III |
| R03-F09, R04-F09: gameplay truth is CPU-deterministic | adopted | FR-U06-005, FR-U06-034 |
| R03-F09, R04-F09: screenshots from the real renderer | superseded | Captures belong to the verification runner (UA-F09) |
| R03-F09, R04-F09: spec shape (5 stories, 12 requirements, …) | superseded | The Spec Kit templates of this repository |
| R04-F09 | superseded | Word for word the same contract as R03-F09 with other consumers |

## Traceability

| Acceptance item of the brief | User story | Requirements | Success criteria |
|---|---|---|---|
| 1 Every experience declares tiers; a tier change never changes the digest | US1 | FR-U06-001 to FR-U06-006 | SC-U06-001, SC-U06-002 |
| 2 Step down under heat or Low Power Mode, recover after the calm period | US2 | FR-U06-010 to FR-U06-015 | SC-U06-003 |
| 3 Records contain launch, prepare, shader compile, first present, pacing, memory, GPU bytes, thermal state | US3, US4 | FR-U06-020, FR-U06-021, FR-U06-024, FR-U06-030 to FR-U06-034, FR-U06-040 to FR-U06-043 | SC-U06-004, SC-U06-006, SC-U06-007 |
| 4 Budgets as proposals with the confirming device measurement | US6 | FR-U06-060 to FR-U06-062 | SC-U06-009 |
| 5 Shaders compiled before the first interactive frame | US3 | FR-U06-022, FR-U06-023 | SC-U06-005 |
| 6 Ten-minute scenario without unbounded growth | US5 | FR-U06-050 to FR-U06-052 | SC-U06-008 |
| Boundaries | all | FR-U06-070 to FR-U06-073 | SC-U06-010 |
