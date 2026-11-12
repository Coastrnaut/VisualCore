# Data model: UA-F05

Types of sections 1 to 5 are pure (`VisualCoreExperience`, Foundation only).

## 1. Storage namespace and names

- Folder: `<root>/<id>/` where `<root>` is `Application Support/Experiences` and `<id>` the experience id.
- Defaults prefix: `exp.<id>.`.
- A name (of a file or of a value): 1 to 128 characters of `A-Z a-z 0-9 . _ -`, not starting with a dot.
- Reserved file names: `state.json`, and `quarantine-<n>.json` for a decimal n. Hidden names (starting with a
  dot) are the temporary files of atomic writes.
- Quota (`StorageQuota`): `maxBytes = 16 MiB` of files, `maxFiles = 64`, `maxValues = 64`,
  `maxValueBytes = 4_096`. Reserved files do not count.

`StorageError` (stable `code`): `.invalidName(String)` (`storage.invalid-name`), `.reservedName(String)`
(`storage.reserved-name`), `.quotaExceeded(String)` (`storage.quota-exceeded`; the text names the bound),
`.notFound(String)` (`storage.not-found`), `.writeFailed(String)` (`storage.write-failed`), `.tooLarge(Int)`
(`storage.too-large`).

## 2. ExperienceStorage (the handle)

Created by the app with an experience id, the root folder and a defaults object.

| Operation | Rule |
|---|---|
| `write(_ data:, to name:)` | name rule; quota; atomic (temporary file `.<name>.tmp-<uuid>` in the folder, then replace); creates the folder |
| `read(_ name:) -> Data` | name rule; `.notFound` without the file |
| `exists(_ name:) -> Bool` | false for an invalid or reserved name |
| `list() -> [String]` | names of the experience's files, sorted; reserved and hidden files are not shown |
| `remove(_ name:)` | name rule; `.notFound` without the file |
| `setValue(_ data:, for key:)` | name rule for the key; at most 4 KiB; at most 64 values; stored under `exp.<id>.<key>` |
| `value(for key:) -> Data?` | nil without the value or for an invalid key |
| `valueKeys() -> [String]` | the keys without the prefix, sorted |
| `removeValue(for key:)` | removes it; no error without it |
| `static removeValues(of id:, in defaults:)`, `static removeAllValues(in defaults:)` | used by a reset: every key with the prefix of the id, or with the prefix `exp.` |

A refused operation changes nothing.

## 3. Saved state

File `state.json` in the experience's folder: the text of `ExperienceSnapshot.encoded()` (format 1; keys
`checksum, digest, experience, format, payload, schema, seed, step`); at most 1,048,576 bytes.

`SavedStateStore(root:)`:

| Operation | Rule |
|---|---|
| `load(_ id:) -> SavedStateLoad` | `.none` without the file; `.unreadable(problem)` when the file is larger than the limit, cannot be read, is not a snapshot (`SnapshotError`), or names another experience; else `.state(snapshot)` |
| `save(_ snapshot:) throws(StorageError) -> Bool` | false and no write when the stored bytes equal the new text; otherwise an atomic write and true |
| `quarantine(_ id:reason:) throws(StorageError) -> String?` | moves `state.json` to `quarantine-<n>.json` (n = the highest existing n + 1, starting at 1); keeps at most 3 copies, removing the lowest n first; nil without a state |
| `quarantined(_ id:) -> [String]` | the names of the copies, by rising n |
| `removeLeftovers() -> Int` | removes every hidden temporary file in every namespace folder; the number removed |
| `remove(_ id:)` | removes `state.json` (used by tests and debug support) |

`SavedStateProblem`: `code: String` (the `SnapshotError` code, `state.too-large`, `state.unreadable-file` or
`snapshot.wrong-experience`), `newer: Bool` (true for `snapshot.newer-schema`), `init(error: SnapshotError)`,
`init(failureCode: String)` (from a session failure of the restore stage).

State transitions of an open:

```
load → .none                → open without a snapshot
     → .state(s)            → open with s and refusedSnapshotFails
                               → running                       (restored)
                               → failed at stage restore        → unreadable message
     → .unreadable(problem) → no open                           → unreadable message
unreadable message → Back   → catalog; the file is untouched
                   → Reset  → quarantine → open without a snapshot
```

## 4. Migration examples

`MigrationExample`: `version: Int` (1 or more, below the current schema), `snapshot: Data` (the stored text),
`expectedDigest: String` (hex). `SnapshotMigrationCheck.problems(for core:, id:, examples:) async -> [String]`:
a text for every missing version, for an example that is not a snapshot of that version and id, for a restore
that is refused, and for a digest that differs.

## 5. Inventory

`InventoryRule`: `kind` (`file` or `key`), `pattern` (a regular expression matched against the whole relative
path or key), `writer` (text), `origin` (text; required when `system` is true), `system: Bool`.
`ContainerInventory(rules:) throws` refuses a system rule without an origin and an invalid pattern.
`unlisted(files:keys:) -> [String]`: the items no rule matches, each prefixed `file:` or `key:`.

The allow-list of the app (debug support; file paths are relative to the container):

| Kind | Pattern (shown as a path) | Writer |
|---|---|---|
| file | `Library/Application Support/Experiences/<id>/state.json` | the app: the saved state |
| file | `Library/Application Support/Experiences/<id>/quarantine-<n>.json` | the app: quarantined copies |
| file | `Library/Application Support/Experiences/<id>/<name>` | the experience, through its handle |
| file | `Library/Preferences/<bundle id>.plist` | the system: the defaults domain of the app |
| key | `vc.shell.preferences` | the app: the session state |
| key | `vc.shell.preferences.unreadable` | the app: the copy of an unreadable session state |
| key | `exp.<id>.<name>` | an experience, through its handle |

System entries (files and keys the system writes on its own) are added in the implementation as they are
observed on the two simulator runtimes, each with the observation that established it; the list as built is
recorded in the "As built" section.

## 6. App and session additions

- `ExperienceOpenRequest.refusedSnapshotFails: Bool` (default false).
- `ExperienceSession.checkpoint()`: hands the open experience's snapshot to the sink when the session is
  running or suspended; counts a sink failure as today.
- `ExperienceLaunch.storage: ExperienceStorage`.
- `ExperienceRegistration.migrationProblems: @Sendable () async -> [String]`.
- `AppModel`: `unreadable: UnreadableState?` (experience id and problem), `resetUnreadable()`,
  `dismissUnreadable()`, `diagnostics.lastSaveFailure`, `diagnostics.leftoversRemoved`.
- `ShellPreferences.migrations` (empty today); key `vc.shell.preferences.unreadable`.

## 7. Identifiers and debug arguments

Identifiers: `vc.unreadable` (the message), `vc.unreadable.reset`, `vc.unreadable.back`, `vc.inventory` (debug
builds, settings diagnostics).

Debug arguments (debug builds only): `-vcDamageState <truncated|garbage|newer|other>` (damages every stored
state before the model starts), `-vcStrayItems` (one stray file and one stray defaults key), and the existing
`-vcSeedData`, which now writes through the storage handle.
