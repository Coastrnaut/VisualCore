# Data Model: A24-P04 (feature 176)

- **Run file version 3** body: `{case: {config, fingerprint, id, plan, version, workload}, report, samples, state,
  summary}`; migration 2 → 3 from the built-in case of the same id and version (fingerprint must match).
- **Saved result** `result-<n>.json`: envelope `a24.saved-result` v1, body `{order, run}`, ≤ 2,162,688 bytes.
- **Index** `results.json`: envelope `a24.result-library` v1, body `{next, entries: [{file, order}]}`.
- **ResultLibraryEntry:** file, order, and either the run (case title, state, interval p50/p95, GPU timed) or the
  refusal code.
- **Caps:** 12 results; messages "The library holds 12 results." and "There is not enough space to save this result.".
- **CSV** `a24.benchmark-run.csv` v1: the `key,value` part, an empty line, the sample table; CRLF; RFC 4180 quoting.
- **ResultExportFile:** url, format (json, csv); `Transferable` with the matching content type.
- **As built (A24-P04):** the repeated-save rule is held by the presenter (`savedRun`: the last saved run is refused
  again with "This result is already saved."), not by the library; the export folder is emptied in the presenter's
  `teardown`, so also after a context rebuild, and the next tap writes the file again.
