# Contract: Visual Programming Lab library and diagnostics (A23-P04)

- **Presenter:** `library` (a `GraphLibrary`, nil without storage), `save(name:)`, `open(file:)`, `rename(file:to:)`,
  `remove(file:)`, `openExample(id:)`; each returns the library's result; opening restores the core through the
  factory's `restoreGraph` closure (as Zen Garden's `restoreDocument`).
- **Identifiers:** `library`, `library-save`, `library-name`, `library-row-<file>`, `library-open-<file>`,
  `library-rename-<file>`, `library-remove-<file>`, `library-message`, `examples`, `example-<id>`,
  `node-diagnostic-<id>`.
- **VisualCore names used:** `ExperienceStorage`, `StorageError`, `StorageQuota`, `MigrationChain`, `ExperienceShell`,
  `ExperienceSnapshot` (and the A23-P03 set).
