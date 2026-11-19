# Research: A24-P04 (feature 176)

- **R1 Settings in the file.** Decision: the whole case in run file version 3 with a recomputed fingerprint. Rationale:
  the phase's regression fixture; a result names what was measured even after the built-in case changes version.
- **R2 Library pattern.** Decision: Visual Programming Lab's `GraphLibrary` shape (files are the truth, an index for the
  counter). Rationale: proven refusal and read-only behaviour (A23-P04).
- **R3 CSV shape.** Decision: a `key,value` part and a sample table in one file. Rationale: one file carries both the
  provenance and the samples; spreadsheet programs open it. Alternative: two files (rejected: the share sheet sends one).
- **R4 Number text.** Decision: Swift's shortest round-trip description. Rationale: exact and stable for golden files.
- **R5 Caps.** Decision: 12 results of at most 2,162,688 bytes. Rationale: a 60 s run at 120 Hz is about 0.7 MB; the
  experience quota is 16 MiB.
