# Feature Specification: UA-F05 — Session state, per-experience persistence, reset and restore

**Feature Branch**: `191-ua-f05-session-persistence` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F05 (migration ledger) · ID namespace FR-U05-###, SC-U05-###, T-U05-###

**Input**: User description: the UA-F05 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/191-ua-f05-session-persistence`; requirement ids FR-U05-###, success
  criteria SC-U05-###, task ids T-U05-###.
- **Names from the brief:** the storage root `Application Support/Experiences/<id>/`, the defaults prefix
  `exp.<id>.`, and the module VisualCorePersistence with `DocumentStore`, `NamedLibrary` and `MigrationChain`, which
  exist. "Its context" (what an experience reaches its storage through) does not exist yet; its name is a proposal
  until `/speckit-plan` confirms it. Other modules are not named here.
- **Who the users are:** a person who leaves an experience and comes back to it — a minute later, or after the
  app was ended; a person who wants to start one experience, or everything, afresh; and the authors of the 100
  experiences, each of whom gets a private place for its saved state.
- **Out of scope:** iCloud and any other sync. Nothing a person saves leaves the device.
- **Device-only item:** the container inventory on a real device after the device campaign. **Owner-only items:**
  none.
- **What exists today (audit of 2026-11-12):** an experience can give a snapshot of its state and take one back,
  with a format, a schema version, a checksum and migrations; the session hands a snapshot to its opener at every
  suspension and at every close and accepts one at an open, but the app passes neither; the app stores the last
  route, the last experience and the catalog filter and restores them (UA-F04); the settings can remove the data
  folder of one experience or of all, but no production code writes into such a folder; no defaults key with the
  prefix `exp.` is written or cleared; nothing quarantines a file; no inventory of the container exists. No
  experience is registered yet, so the behaviour is proven with the sample experience and the app's debug
  experience.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Come back and find the experience where it was left (Priority: P1) 🎯

A person plays with an experience, leaves it or puts the app away, and later comes back — also after the app
was ended in the meantime. The experience is as it was: the same state, not a fresh start. Nothing had to be
saved by hand.

**Why this priority**: acceptance items 2 and 3 and rule E-05. An app that forgets what a person made is not
trusted with anything.

**Independent Test**: change the state of a test experience, end the app, start it again and compare the state
with the one before; repeat with a close of the experience instead of an end of the app.

**Acceptance Scenarios**:

1. **Given** an experience whose state was changed, **When** the app goes to the background, **Then** the state
   is saved without any action of the person, and a start of the app after it was ended shows the same state.
2. **Given** an experience whose state was changed, **When** the person leaves it for the launcher and opens it
   again, **Then** it shows the same state.
3. **Given** a running experience, **When** a state change was accepted and the experience keeps running,
   **Then** the state is saved at the next safe point, at most a stated time after the change, so that an abrupt
   end of the app loses at most that much.
4. **Given** a start of the app after it was ended, **When** the last route was an experience, **Then** the
   app returns to that experience with its saved state; the last route, the last experience and the catalog
   filter are as they were.
5. **Given** an experience that never changed since it was opened, **When** it is suspended or closed,
   **Then** what is stored for it is the same as before.
6. **Given** a save that is interrupted at any point, **When** the app starts again, **Then** the stored state is
   either the complete earlier one or the complete new one, never a part of one.

---

### User Story 2 - A saved state that cannot be read never crashes and never vanishes (Priority: P1)

A saved state can be cut off, damaged, or written by a newer version of the app. When that happens the person
is told in plain words, can start that experience afresh with one action, and can simply go back. The unreadable
file is kept aside; it is never thrown away silently.

**Why this priority**: acceptance item 3. Reading what an earlier run wrote is the place where an app most
easily crashes at start, again and again.

**Independent Test**: put a cut-off, a damaged and a newer-version state in the place of a saved one, open the
experience, and observe the message, its two actions, the kept copy and the absence of a crash.

**Acceptance Scenarios**:

1. **Given** a stored state that is cut off, damaged, of another experience or of an unknown format, **When**
   the experience is opened, **Then** the app shows a message that the saved state could not be read, with the
   actions Reset and Back, and does not crash.
2. **Given** a stored state of a newer version than the app understands, **When** the experience is opened,
   **Then** the same message appears and says that a newer version wrote it.
3. **Given** the message, **When** Reset is chosen, **Then** the experience starts as from a fresh preparation,
   and the unreadable state is kept as a quarantined copy.
4. **Given** the message, **When** Back is chosen, **Then** the launcher is shown and the stored state is as it
   was: nothing was overwritten and nothing was removed.
5. **Given** an unreadable stored state, **When** the experience is opened repeatedly without choosing Reset,
   **Then** the message appears every time and the stored state stays untouched.
6. **Given** several unreadable states over time, **When** copies are quarantined, **Then** at most a stated
   number of copies is kept per experience and the oldest is removed first.

---

### User Story 3 - Each experience reaches only its own storage (Priority: P1)

An experience gets one handle to its storage. Through it, it reads and writes files in its own folder and
values under its own defaults prefix — and nothing else. It cannot name a path or a key of another experience
or of the app.

**Why this priority**: acceptance item 1. A hundred experiences share one container; without this rule one
faulty experience could damage the saved state of all the others.

**Independent Test**: give two test experiences their handles, let each write a file and a value, and try from
each to read, list, overwrite and remove what the other wrote, with ordinary names and with names built to
escape (`..`, absolute paths, separators, another experience's prefix).

**Acceptance Scenarios**:

1. **Given** two experiences that each wrote a file and a value, **When** each lists and reads through its
   handle, **Then** it sees its own data and none of the other's.
2. **Given** a handle, **When** a name is used that would leave the experience's folder or its prefix, **Then**
   the operation is refused with a reason and nothing is read, written or removed.
3. **Given** a handle, **When** more is written than the experience's quota allows, **Then** the write is
   refused and what was stored before stays intact.
4. **Given** the source of an experience, **When** it is checked, **Then** it contains no direct use of the
   container's paths or of the shared defaults.

---

### User Story 4 - Start one experience afresh, or everything (Priority: P2)

A person can reset one experience: its saved state, its files, its values and its quarantined copies are
removed and it starts afresh; nothing else changes. A person can reset all data: every experience's storage and
the app's own session state are removed and the app is as after a first start.

**Why this priority**: acceptance item 4 and rule E-06.

**Independent Test**: give three experiences stored data, reset one and compare what is left; then reset all
and compare again.

**Acceptance Scenarios**:

1. **Given** three experiences with stored data, **When** one is reset after the confirmation, **Then** exactly
   its folder and its values under its prefix are gone, the two others and the app's session state are
   unchanged.
2. **Given** stored data and a stored session state, **When** all data is reset after the confirmation,
   **Then** no experience folder, no value under any experience prefix and no session state is left, and the
   welcome appears as on a first start.
3. **Given** an open experience, **When** it is reset, **Then** it is closed first, and no state saved by that
   close survives the reset.
4. **Given** a reset experience, **When** it is opened again, **Then** it is in the state of a fresh
   preparation with the same seed.

---

### User Story 5 - A state saved by an older version still opens (Priority: P2)

When an experience changes the shape of its saved state, states saved by every earlier version still open and
give the state a person left. Every experience that stores data proves this with a stored example of every
earlier version.

**Why this priority**: acceptance item 5. The app will be updated many times; saved work must survive each
update.

**Independent Test**: open stored examples of every earlier schema version of the sample experience and compare
the result with the expected state; remove one example and see the check fail.

**Acceptance Scenarios**:

1. **Given** a stored state of an earlier schema version, **When** the experience is opened, **Then** the state
   is migrated and shown, and the next save writes the current version.
2. **Given** an experience whose schema version is above 1, **When** its migration check runs, **Then** it
   needs a stored example for every earlier version and fails for a missing one.
3. **Given** an earlier version for which no migration exists, **When** such a state is opened, **Then** it is
   handled as an unreadable state (User Story 2), not as a crash.

---

### User Story 6 - The app's container holds only what is allowed (Priority: P2)

After the app was used — experiences opened, states saved, a state quarantined, a reset — the app's container
holds only files and defaults keys from a written allow-list. A file or key nobody listed fails the check; it is
never ignored.

**Why this priority**: acceptance item 6. The inventory is the proof that nothing writes where it should not,
and that no unlock flag or tracking value is ever stored.

**Independent Test**: use the app in an interface test, read the inventory and compare it with the allow-list;
add a stray file and see the check fail.

**Acceptance Scenarios**:

1. **Given** the app after a scripted use, **When** the inventory is taken, **Then** every file and every
   defaults key matches an entry of the allow-list.
2. **Given** a file or a key that matches no entry, **When** the inventory is checked, **Then** the check fails
   and names it.
3. **Given** files or keys the system itself writes, **When** they are on the allow-list, **Then** each entry
   states where it comes from and how that was established.

---

### Edge Cases

- **A save fails** (no space, a write error): the earlier stored state stays intact, the failure is recorded in
  the diagnostics, the experience keeps running, and the next save is tried again.
- **The app is ended during a save**: the stored state is the complete earlier one or the complete new one; a
  leftover temporary file is removed at the next start and never counted as a state.
- **Leaving while an experience prepares**: nothing is saved and nothing stored is changed.
- **An experience fails while running**: the last state that was saved stays; the failed state is not saved.
- **Backgrounding and interruptions**: a suspension saves once; a second notice for the same suspension saves
  nothing again.
- **Memory pressure**: when the session closes an experience under memory pressure, its state is saved before
  the close like at any other close.
- **Damaged, cut-off or newer stored state**: User Story 2. A state whose checksum is right and whose content
  does not give its own digest back is unreadable as well.
- **A stored state of an experience that is no longer available**: it is kept untouched; a reset of all data
  removes it.
- **A stored state larger than the limit**: it is unreadable (never loaded into memory in full).
- **Reset while the unreadable-state message is shown**: the reset of the message and the reset in the settings
  do the same.
- **Two starts in quick succession**: the second start reads what the first one completed; no partial file is
  taken as a state.
- **Damaged or newer session state of the app**: as in UA-F04, the app starts with defaults and notes it; this
  feature adds that the unreadable value is not overwritten before the person changed a preference.

## Requirements *(mandatory)*

### Functional Requirements

**Storage of an experience**

- **FR-U05-001**: Each experience MUST have one storage namespace derived from its id: the folder
  `Application Support/Experiences/<id>/` and the defaults prefix `exp.<id>.`.
- **FR-U05-002**: An experience MUST reach its storage only through one handle that is given to it when it is
  created. The handle MUST offer reading, writing, listing and removing of named files in the experience's
  folder and of named values under its prefix, and nothing outside them.
- **FR-U05-003**: A name MUST be 1 to 128 characters of letters, digits, `.`, `_` and `-`, and MUST NOT start
  with a dot. Any other name, and any name that would leave the namespace, MUST be refused with a reason; a
  refused operation MUST change nothing.
- **FR-U05-004**: The storage of one experience MUST be bounded: at most 16 MiB of files and at most 64 files,
  and at most 64 values of at most 4 KiB each. A write beyond a bound MUST be refused and MUST leave what was
  stored intact.
- **FR-U05-005**: Writes through the handle MUST be atomic: after an interruption a file holds its complete
  earlier content or its complete new content.
- **FR-U05-006**: Experience sources MUST NOT use the container's paths, the shared defaults or another
  experience's namespace directly; a check MUST fail when they do.

**Saving**

- **FR-U05-010**: The state of an open experience MUST be saved without any action of the person: at every
  suspension, at every close (leaving, opening another experience, a close under memory pressure), and at safe
  points while it runs.
- **FR-U05-011**: A safe point MUST follow an accepted state change by at most 5 seconds while the experience
  keeps running; without a state change since the last save nothing MUST be written.
- **FR-U05-012**: The saved state MUST be the snapshot the experience contract defines, stored in the
  experience's namespace; it MUST be at most 1 MiB.
- **FR-U05-013**: A save MUST be atomic and MUST NOT block the experience for longer than one save of the
  largest allowed state takes; a failed save MUST keep the earlier stored state, MUST be recorded in the
  diagnostics and MUST NOT stop the experience.
- **FR-U05-014**: The state of a failed experience and of a cancelled preparation MUST NOT be saved.
- **FR-U05-015**: A leftover temporary file of an interrupted save MUST be removed at the next start and MUST
  never be read as a state.

**Restoring**

- **FR-U05-020**: When an experience is opened and a stored state exists, the experience MUST start in that
  state: the same state digest, seed and step as when it was saved.
- **FR-U05-021**: After the app was ended and started again, the last route, the last experience and the
  catalog filter MUST be restored as UA-F04 defines, and an experience restored as the last route MUST show its
  saved state.
- **FR-U05-022**: Without a stored state an experience MUST start from a fresh preparation with its seed.
- **FR-U05-023**: A stored state of an earlier schema version MUST be migrated when it is read; the next save
  MUST write the current version.

**Unreadable states**

- **FR-U05-030**: A stored state that is cut off, damaged, larger than the limit, of another experience, of an
  unknown format, of a newer schema version, without a migration from its version, or whose content does not
  give its digest MUST be treated as unreadable: the app MUST NOT crash and MUST NOT start the experience with
  a part of it.
- **FR-U05-031**: For an unreadable state the app MUST show a message in plain words with the actions Reset
  and Back; the message MUST say when a newer version of the app wrote the state, and MUST carry a stable code
  for the diagnostics.
- **FR-U05-032**: Before anything is written over an unreadable state, a copy of it MUST be quarantined inside
  the experience's namespace. At most 3 quarantined copies MUST be kept per experience; the oldest MUST be
  removed first.
- **FR-U05-033**: Back MUST leave the stored state untouched. Reset MUST quarantine it and start the experience
  from a fresh preparation.
- **FR-U05-034**: An unreadable state MUST never be overwritten by an automatic save: while the message is
  shown no experience runs, so nothing is saved.

**Reset**

- **FR-U05-040**: The reset of one experience MUST remove exactly its folder (saved state, files, quarantined
  copies) and its values under its prefix, and MUST leave every other experience's storage and the app's session
  state unchanged.
- **FR-U05-041**: The reset of all data MUST remove every experience folder, every value under an experience
  prefix and the app's session state, also for experiences that are no longer available, and MUST show the
  welcome as on a first start.
- **FR-U05-042**: A reset MUST close an open experience first, and no state saved by that close MAY survive the
  reset.
- **FR-U05-043**: After its reset an experience MUST open in the state of a fresh preparation with the same
  seed.
- **FR-U05-044**: Both resets stay behind a confirmation as UA-F04 defines; the Reset of the unreadable-state
  message is itself the confirmed action for that experience.

**Migrations**

- **FR-U05-050**: An experience whose schema version is above 1 MUST carry a stored example of a saved state
  for every earlier version, and a check MUST prove for each example that it opens and gives the expected state
  digest.
- **FR-U05-051**: The check MUST fail when an example for an earlier version is missing, does not open or gives
  another digest, and it MUST run for every registered experience.
- **FR-U05-052**: The app's own session state MUST keep its version; a later version MUST migrate an earlier
  one instead of dropping it.

**Inventory**

- **FR-U05-060**: An inventory MUST list every file of the app's data container and every key of the app's
  defaults, and compare each with a written allow-list; anything unlisted MUST fail the check and be named.
- **FR-U05-061**: The allow-list MUST state for every entry what writes it; an entry for something the system
  writes MUST state how its origin was established. Unknown items MUST never be suppressed.
- **FR-U05-062**: The inventory MUST be taken in an interface test after a scripted use of the app (open, save,
  quarantine, reset of one, reset of all) on both simulator runtimes.
- **FR-U05-063**: The allow-list MUST contain no entry for an unlock flag, an advertising or tracking value or
  an account.

**Boundaries and verification**

- **FR-U05-070**: Nothing this feature stores MUST leave the device: no sync, no network, no shared container.
- **FR-U05-071**: Code that reads stored data in the shipped app MUST contain no deliberate crash on bad data.
- **FR-U05-072**: Every public symbol added to the framework MUST be documented, the API baseline MUST be
  updated, and the reference regression MUST pass. Pure logic MUST be tested without a display.
- **FR-U05-073**: Test access (seeding stored states, damaging them, reading the inventory) MUST exist only in
  builds made for testing.
- **FR-U05-074**: The container inventory on a real device MUST be listed as a device task that runs only
  after ImplementationLock-100.

### Key Entities

- **Storage namespace**: the folder and the defaults prefix of one experience.
- **Storage handle**: what an experience is given to reach its namespace.
- **Saved state**: the stored snapshot of one experience: experience id, schema version, seed, step, digest,
  content, checksum.
- **Quarantined copy**: an unreadable saved state kept aside, with the time and the reason.
- **Unreadable-state message**: the reason (damaged, newer version), its code, the actions Reset and Back.
- **Session state**: the app's own stored preferences (UA-F04): welcome seen, last route, catalog filter, the
  settings.
- **Migration example**: a stored saved state of one earlier schema version with its expected digest.
- **Allow-list entry**: a pattern of a file or a defaults key, who writes it, and for system items how that was
  established.

## Success Criteria *(mandatory)*

### Measurable Outcomes

All outcomes are verified on the host or on simulators; the container inventory on real devices is the device
task of FR-U05-074.

- **SC-U05-001**: In 20 of 20 attempts with names built to escape, an experience reads, lists, changes and
  removes 0 items of another experience or of the app; 2 experiences see only their own data.
- **SC-U05-002**: After the app was ended and started again, the last route, the last experience and the
  catalog filter are restored in 3 of 3 cases, and the restored experience has the same state digest as before.
- **SC-U05-003**: A state change is on disk at most 5 seconds after it was accepted; with no change, 0 bytes are
  written by 10 further safe points.
- **SC-U05-004**: Of 8 unreadable states (cut off, not a state at all, wrong checksum, another experience,
  unknown format, newer version, missing migration, too large), 8 give the message with Reset and Back, 0 crash,
  and 0 are overwritten before Reset or a quarantine.
- **SC-U05-005**: A save interrupted at each of its steps leaves, in 100% of the cases, the complete earlier or
  the complete new state, and 0 temporary files after the next start.
- **SC-U05-006**: A reset of one of three experiences removes 100% of its files and values and 0 of the others';
  a reset of all leaves 0 experience files, 0 experience values and no session state.
- **SC-U05-007**: 100% of the experiences with a schema version above 1 have an example for every earlier
  version that opens with the expected digest; removing 1 example fails the check in 1 of 1 attempts.
- **SC-U05-008**: After the scripted use, the inventory finds 0 unlisted files and 0 unlisted defaults keys on
  both simulator runtimes; 1 stray file and 1 stray key each fail it.
- **SC-U05-009**: At most 3 quarantined copies exist per experience after 5 unreadable states in a row.
- **SC-U05-010**: 100% of the new public framework symbols are documented, the API baseline check passes, the
  reference regression passes 7 of 7, and a release build of the app contains 0 symbols of the test access.

## Assumptions

- "Its context" is one storage handle per experience, given by the app when it creates the experience; the name
  and the place of the type are decided in the plan.
- A safe point is a moment at which the experience's state is consistent between two steps; the app chooses
  them, the experience does not have to announce them.
- The seed of an experience stays the stable value UA-F04 derives from its id; the saved state carries it, and
  a reset returns to it.
- The quarantined copies live inside the experience's namespace, so that the reset of that experience removes
  them and no folder outside the namespaces has to be allowed.
- The bounds of FR-U05-004 are large enough for every launch experience's saved state (at most 1 MiB) and small
  enough that a faulty experience cannot fill the device; an experience that needs more asks for it in its own
  integration feature.
- The inventory covers the app's data container (documents, application support, caches, temporary files) and
  the app's own defaults domain; files the system keeps outside the app's reach are not part of it.
- StoreKit's and Metal's files are named by the brief; StoreKit's appear only with UA-F08, so their allow-list
  entries are written when they are first observed, with their provenance.
- The saved state of the sample and the debug experience is enough to prove the behaviour until the first real
  experience is integrated (UA-F07).

## Absorbed source requirements

| Source requirement | Decision | Where |
|---|---|---|
| R02-F28: checksum JSON for stored profiles | adopted | FR-U05-012 (the snapshot of the experience contract carries a checksum), FR-U05-030 |
| R02-F28: transactional (atomic) saves | adopted | FR-U05-005, FR-U05-013; SC-U05-005 |
| R02-F28: versioned objectives (versioned stored progress) | adopted | FR-U05-012, FR-U05-023 |
| R02-F28: recovery state after a failed or damaged save | adopted | FR-U05-030 to FR-U05-034 |
| R02-F28: schema migration between versions | adopted | FR-U05-023, FR-U05-050 to FR-U05-052 |
| R02-F28: prerequisite R2-F23; consumers: all Round 2 games | superseded | The gate depends on UA-F03 and UA-F04; every experience uses the storage handle |
| R02-F28: error handling for storage failures | adopted | FR-U05-013, Edge Cases |
| R02-F28: deterministic tests | adopted | FR-U05-072; restore gives the same digest (FR-U05-020) |
| R02-F28: observability of save and migration outcomes | adopted | FR-U05-013, FR-U05-031 (diagnostics, stable codes) |
| R02-F28: accessibility of related messages | adopted | FR-U05-031 (plain words, two actions; the message is part of the audited routes) |
| R02-F28: copyright and originality statement, excluded scope | superseded | Constitution X and this specification's scope |
| R02-F28: requirement ids under R2-F28 | superseded | Ids are FR-U05-### |
| R02-F28: storage path `Application Support/<Game>/v1/progress.json` | superseded | The experience's namespace (Auto-Creator.md section 21) |
| R02-F28: "$1.99–$4.99 one-time purchase … no IAP" | superseded | CLAUDE.md rule 3: one USD 1.99 non-consumable |

## Traceability

| Acceptance item of the brief | User story | Requirements | Success criteria |
|---|---|---|---|
| 1 An experience reaches only its own storage | US3 | FR-U05-001 to FR-U05-006 | SC-U05-001 |
| 2 Last route, experience and filter restored after termination | US1 | FR-U05-020 to FR-U05-023 | SC-U05-002 |
| 3 Atomic autosave; unreadable state gives a message with Reset, a quarantined copy, no crash | US1, US2 | FR-U05-010 to FR-U05-015, FR-U05-030 to FR-U05-034 | SC-U05-003, SC-U05-004, SC-U05-005, SC-U05-009 |
| 4 Reset of one clears exactly its namespace; reset of all clears everything | US4 | FR-U05-040 to FR-U05-044 | SC-U05-006 |
| 5 A migration test from every earlier schema version | US5 | FR-U05-050 to FR-U05-052 | SC-U05-007 |
| 6 Container inventory lists only allowed files and keys | US6 | FR-U05-060 to FR-U05-063 | SC-U05-008 |
| Boundaries | all | FR-U05-070 to FR-U05-074 | SC-U05-010 |
