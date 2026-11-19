# Contract: Graphics Benchmark Lab results and export (A24-P04)

- **Core:** `RunDocument.schemaVersion = 3`; `RunCSV.text(of: BenchmarkRun) -> String`, `RunCSV.format =
  "a24.benchmark-run.csv"`, `RunCSV.version = 1`.
- **Experience:** `ResultLibrary(storage:)` with `list()`, `save(_ run:) -> Result<Int, ResultLibraryFailure>`,
  `open(file:)`, `remove(file:)`, `maxResults = 12`; `ResultExportFile: Transferable`; `ResultsView`.
- **Identifiers** (prefixed `experience.a24.graphics-benchmark-lab.`): `results`, `result-save`, `result-row-<n>`,
  `result-open-<n>`, `result-remove-<n>`, `result-export-json`, `result-export-csv`, `result-share`, `results-done`.
- **As built (A24-P04):** also the identifiers `result-message` (the library's last message) and `result-opened` (the
  opened result's block); `ResultLibrary.save(_:)` returns the file number n; the failures add `noRun`, `exportFailed`
  and `run(code)` (codes prefixed `a24.`); `result-remove-<n>` removes at once (no confirmation over the drawing).
