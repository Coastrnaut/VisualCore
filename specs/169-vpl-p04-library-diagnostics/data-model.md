# Data Model: A23-P04 (feature 169)

- **Saved graph file** `graph-<n>.json`: envelope kind `a23.saved-graph`, version 1, body `{name, order, graph}`;
  at most 81,920 bytes; name trimmed 1…40, unique ignoring case; order = largest + 1 on save, kept on rename.
- **Library index** `library.json`: envelope kind `a23.graph-library`, version 1, body `{next, entries: [{file, name,
  order}]}`.
- **Limits and messages:** 24 graphs; "The library holds 24 graphs.", "A name has 1 to 40 characters.", "A graph is
  already called <name>."
- **GraphLibraryEntry:** `file`, `name`, `order`, `state` (`readable` or `unreadable(code)`).
- **GraphLibraryFailure:** `full`, `badName`, `taken(name)`, `unreadable(code)`, `missing`, `storage(StorageError)`,
  `unavailable`; `message`.
- **LabExample:** `id` (`clouds`, `soft-gradient`, `mixed-clouds`), `title`, `graph`, `licence`.
- **NodeDiagnostics:** `[NodeID: [String]]` from `GraphDiagnostics.byNode(_:in:)`.
- **As built (A23-P04):**
  - `GraphLibraryFailure` also has `readOnly` (a `library.json` of a newer version is never overwritten; opening still
    works) and `graph(code)` (`GraphDocument.encode` refuses the graph); an oversized write is `storage(tooLarge)`.
  - `GraphDiagnostics` exposes its sentences as constants and helpers (`emptyInput(_:)`, `outputDisconnected`,
    `partOfLoop`, `multipleOutputs`, `duplicateEdge`, `duplicateNode`, `unknownParameter(_:)`,
    `parameterOutOfRange(_:)`); a taken input reuses `EditMessages`' sentence, which names its node.
  - The library's sentences are shown in `library-message` with an accessibility label; they are not announced,
    because the experience target does not depend on VisualCoreSimulation's announcement kinds.
