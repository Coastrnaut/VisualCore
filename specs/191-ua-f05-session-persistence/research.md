# Research: UA-F05 — Session state, per-experience persistence, reset and restore

Read-only audit of 2026-11-12 (by an audit agent at `a426e55`; the facts the design rests on were checked again
by the lead at `HEAD`), followed by the decisions.

## 1. Audit of the sources the brief names

### Auto-Creator.md section 15.1 (lines 3071 to 3085) and related rules

- Namespace per experience: files under `Application Support/Experiences/<id>/`, defaults keys with the prefix
  `exp.<id>.`; storage is reached only through "its context"; a test proves two experiences cannot read each
  other's data.
- Snapshots are versioned envelopes with migrations; writes are atomic; a migration test from every earlier schema
  version for each experience with stored data.
- Autosave at suspension and at safe points. A truncated, corrupted or newer-version file gives a recoverable
  message with Reset, a quarantined copy is kept, never a crash, earlier work is never erased silently.
- Reset of one experience clears exactly its namespace; reset of all clears every namespace and the session state.
- A container inventory test lists the only files and defaults keys that may exist; system files (the StoreKit
  defaults key, Metal cache files) are allowed after their origin is checked; unknown files are never suppressed.
- No iCloud, no sync.
- Related: E-05 (saved at suspension and safe points; restores to the same digest), E-06 (Reset = fresh preparation
  with the same seed, clears only its own storage), 11.4 (the open request carries an optional snapshot; the
  session hands snapshots to a sink the opener supplies), 11.6 (termination is safe because state was saved at
  suspension; shipped paths that read stored data use no deliberate crash).

### `Packages/VisualCore/Sources/VisualCorePersistence` (Foundation only)

- `DocumentStore<Value>`: one JSON file per id with an envelope (`kind`, `schemaVersion`, `savedAt`, `payload`);
  atomic write through a hidden temporary file in the same folder and `replaceItemAt` or `moveItem`
  (`DocumentStore.swift:79-90`); size limit (default 256 KiB); reading never moves or deletes a file; the folder
  form of `load()` removes leftover temporary files. `StoreProblem` (corrupt, wrongKind, newerVersion, tooLarge,
  notFound, writeFailed, invalidID). Ids match `^[A-Za-z0-9._-]{1,128}$` and do not start with a dot.
- `MigrationChain(currentVersion:steps:)` with `migrate(_:from:)`; `MigrationError` (missingStep, newerVersion).
- `NamedLibrary`, `TemporaryFolder`: not needed here.
- `DocumentEnvelope` exists and is used by nothing. **No quarantine anywhere.**

### The snapshot of the experience contract (verified)

- `ExperienceSnapshot` (`VisualCoreExperience/ExperienceSnapshot.swift`): `format = 1`, `maxBytes = 1_048_576`;
  fields experience id, schema version, seed, step index, digest, payload text, checksum; `init(data:)
  throws(SnapshotError)` (size, shape, format, fields, checksum, payload is an object); `encoded()` gives
  deterministic JSON. `SnapshotError` has stable codes (`snapshot.wrong-experience`, `snapshot.unknown-format`,
  `snapshot.newer-schema`, `snapshot.missing-migration`, `snapshot.corrupt`, `snapshot.checksum-mismatch`,
  `snapshot.too-large`, `snapshot.state-mismatch`).
- `ExperienceEngine.restore(_:)` checks, in order: experience id, schema not newer, checksum, migration, decode,
  digest; a refused restore changes nothing.
- `ExperienceOpenRequest` (`ExperienceOpenRequest.swift:12-32`): `snapshot: ExperienceSnapshot?`; documented as
  "a refused snapshot is recorded and the open goes on".
- `ExperienceSession`: `SnapshotSink = @MainActor (ExperienceSnapshot) throws -> Void`, fixed at creation; the sink
  is called at a suspension and at every full close (leave, replacing open, memory-pressure close); not at a
  failure, not at a cancelled preparation, never while running; a refused restore only sets
  `lastRestoreRefusal`, and the open continues with the fresh state. `SessionStage.restore` exists and no path
  fails at it. **There is no call that says "save now".**
- `ExperienceActionPort.revision` grows with every accepted action.
- `SampleExperience.snapshotV1(seed:)` and `snapshotV1Digest` exist (the sample core has schema 2 with one step).

### The app as built by UA-F04 and UA-F06

- `AppModel` creates `ExperienceSession()` without a sink and opens without a snapshot; `seed(for:)` is derived
  from the id; `restoreRoute()` opens the experience of a restored route; `reset(_:)` closes the session, removes
  namespace folders and, for all data, the preferences.
- `ExperienceDataStore` (app-internal): `folder(for:)`, `ensure(namespace:)`, `existing()`, `remove(namespaces:)`.
- `PreferencesStore`: one JSON value under `vc.shell.preferences`; an unreadable or newer value gives defaults and a
  note.
- `ExperienceLaunch` (two accessibility choices) is what the registration's factory receives.
- No production code writes below a namespace folder; no `exp.<id>.` key is written or cleared.
- Debug arguments: `-vcResetData`, `-vcSeedData` (writes `seed.txt` into two namespace folders), and others.

### Absorbed archive feature

`R02-F28` (checksum JSON, transactional saves, versioned stored progress, recovery state, schema migration); the
decisions per requirement are in the specification's table.

## 2. Decisions

### R1. The storage handle

**Decision**: `ExperienceStorage` (new, in `VisualCoreExperience`, Foundation only): a value created by the app
for one experience id with the storage root and a defaults object. It offers named files (`write`, `read`,
`list`, `remove`, `exists`) in `Experiences/<id>/` and named values under `exp.<id>.` (`setValue`, `value`,
`valueKeys`, `removeValue`). Names follow the rule of the specification; the reserved names `state.json` and
`quarantine-<n>.json` and hidden names are refused. Writes are atomic (temporary file in the same folder, then
replace). Quotas: 16 MiB and 64 files, 64 values of at most 4 KiB. `ExperienceLaunch` (app) gains `storage`.
**Rationale**: clarification 1; the pure module already depends on the persistence module and may use
Foundation; the tests the brief's first evidence command runs can cover it. **Alternatives**: a handle in the
host module (not reachable by a pure experience module); `DocumentStore` as the handle (its envelope and kinds
are not what an experience wants for arbitrary files).

**Correction at implementation (2026-11-12)**: the source rule of feature 187 (FR-U01-036, script test
`ExperienceModuleTests`) forbade `FileManager` and `UserDefaults` in every file of `VisualCoreExperience`. The
rule now names the two storage files (`ExperienceStorage.swift`: both names; `SavedStateStore.swift`:
`FileManager`) as the only exceptions; every other file of the module and every other forbidden word stay as
they were, and the test fails when one of the two files disappears.

### R2. The saved state

**Decision**: `SavedStateStore` (new, `VisualCoreExperience`): `load(_ id:) -> SavedStateLoad` (`.none`,
`.state(ExperienceSnapshot)`, `.unreadable(SavedStateProblem)`), `save(_ snapshot:) -> Bool` (false when the stored
text is equal), `quarantine(_ id:)`, `quarantined(_ id:)`, `removeLeftovers()`. The file is
`Experiences/<id>/state.json` with the snapshot's own text; quarantined copies are `quarantine-<n>.json` with
rising n, at most 3. The file is read only up to `ExperienceSnapshot.maxBytes`.
**Rationale**: clarification 2 (one version system). **Alternative**: `DocumentStore<ExperienceSnapshot>` (two
versions, a second escaping of the payload, a limit above 1 MiB).

### R3. Unreadable states

**Decision**: file-level problems are found by `SavedStateStore.load`: the app then does not open and shows the
message. Problems only the experience can find are found by the session: `ExperienceOpenRequest` gains
`refusedSnapshotFails` (default false); with it a refused restore ends the open as a `SessionFailure` of the stage
`.restore` before any render host exists. The app maps both to one `SavedStateProblem` (a stable code; `newer`
for `snapshot.newer-schema`) and shows `UnreadableStateView` with Reset (quarantine, then a fresh open) and Back.
**Rationale**: clarification 4; `SessionStage.restore` already exists for this. **Alternative**: let the open go
on and close it afterwards (a fresh state would be shown and could be saved over the unreadable one).

### R4. When a save happens

**Decision**: the app gives the session a sink that calls `SavedStateStore.save`. The session gains
`checkpoint()` (hands the open experience's snapshot to the sink now). The app watches the action port's
`revision`; a change schedules one checkpoint 5 seconds later (further changes inside that time do not move it).
Suspension and close use the existing sink calls. A save whose text equals the stored text writes nothing. A
failed save is recorded in the app's diagnostics; the experience goes on.
**Rationale**: clarification 3; FR-U05-010 to FR-U05-014. Everything runs on the main actor; a save of at most
1 MiB is a few milliseconds. **Alternative**: a timer that saves every few seconds (writes although nothing
changed).

### R5. Reset

**Decision**: `AppModel.reset` keeps its order (close the session, then remove) and additionally removes the
defaults keys with the prefix of the experience, or every key with the prefix `exp.` for all data, and the
quarantined copy of the app's own preferences. The folders already hold the saved state and the quarantined
copies. The Reset of the unreadable-state message quarantines and opens afresh; the reset in the settings removes
the namespace as before.

### R6. Migration examples

**Decision**: `MigrationExample` (version, the stored text, the expected digest) and
`SnapshotMigrationCheck.problems(for:id:examples:)` (pure, async): for every version from 1 below the core's
current version there must be an example, and restoring it in an engine of that core must give the expected
digest. `ExperienceRegistration` gains a closure that runs the check for its core; the app's unit test runs it
for every registered experience. The sample experience uses its existing version 1 snapshot.

### R7. The app's own session state

**Decision**: `ShellPreferences` keeps schema 1. A table of migrations from earlier versions is added (empty
today) with a test that it covers every version below the current one. `PreferencesStore` keeps one copy of an
unreadable or newer stored value under `vc.shell.preferences.unreadable` before the value is overwritten; the
reset of all data removes it.

### R8. Inventory

**Decision**: `ContainerInventory` (pure): rules (`kind` file or key, a pattern, who writes it, and for system
entries how the origin was established) and `unlisted(files:keys:)`. The rule list is a constant of the app's
debug support; the debug support reads the container (documents, application support, caches, preferences,
temporary files) and the app's defaults domain and shows the result in the settings diagnostics (`vc.inventory`).
`PersistenceUITests` reads it after a scripted use; a debug argument adds one stray file and one stray key.
**Rationale**: clarification 5; FR-U05-073 keeps the reader out of release builds. System entries are added as
they are observed on the simulators, each with its observation.

### R9. The rule for experience sources

**Decision**: `scripts/check_app_isolation.py` gains `--no-direct-storage <paths>`: it fails for
`UserDefaults`, `FileManager`, `NSHomeDirectory`, `NSTemporaryDirectory`, `applicationSupportDirectory`,
`documentDirectory` and `cachesDirectory` in the given sources. It is run on the debug experience and on the
sample core today and on every experience module when it is integrated.

### R10. Running the interface tests

**Decision**: `PersistenceUITests` is a fifth chunk (`-e`) of the app test runs; the brief's `xcodebuild test
-only-testing:VisualCoreUITests/PersistenceUITests` command is issued by `scripts/xcodebuild_app.py`.

## 3. Names from the brief, confirmed or corrected

| Name in the brief | Result |
|---|---|
| "its context" | new: `ExperienceStorage`, handed over in `ExperienceLaunch` (R1) |
| storage root `Application Support/Experiences/<id>/` | exists as the root of `ExperienceDataStore`; kept |
| defaults prefix `exp.<id>.` | new: written only through `ExperienceStorage`; cleared by a reset (R5) |
| `DocumentStore`, `NamedLibrary`, `MigrationChain` | exist; the saved state uses the snapshot's own text and `MigrationChain` through the experience contract, not `DocumentStore` (R2) |
| "versioned envelopes (`DocumentEnvelope`)" | `DocumentEnvelope` is unused; the envelope of a saved state is `ExperienceSnapshot` |
| quarantine, container inventory, `PersistenceUITests` | new (R2, R8, R10) |
| "safe points" | an accepted action followed by a checkpoint within 5 seconds (R4) |
| "session state" | `ShellPreferences` under `vc.shell.preferences` (UA-F04) |
