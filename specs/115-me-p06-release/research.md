# Research: A15-P06 (feature 115)

## D1 — Privacy and credits
- **Decision**: one note listing the four small files and the session state in the experience's folder, that only the
  file the person picks is read once and copied, nothing is sent, deletion through the app's data reset or deleting the
  app; credits PubChem (public domain 3D conformers), the element data sources of `data-sources.md` with their licenses.
- **Alternatives**: credits only in acknowledgements (rejected: the release check requires the note).

## D2 — Claim words and source scan
- **Decision**: clarifications Q2–Q3; shell scripts as in A14-P06. **Rationale**: one pattern per gate, easy to rerun.

## D3 — Interface journeys
- **Decision**: chunk `w2` (serial), two suites per clarification Q4; the document picker is never presented
  (the import is proved by package tests; a picker in an unattended run would wait for a person).

## D4 — Recovery, samples, examples
- **Decision**: clarification Q5, following `SolarRecoveryDrawTests`, `SavedViewSampleTests`, `SolarSchemaExampleTests`.

## D5 — Device campaign
- **Decision**: ME-D1 … ME-D6: frame pacing on D1–D3 with caffeine in both modes, touch orbit and picking, VoiceOver
  journey, Dynamic Type, import from Files, thermal and memory over a short session; all `pending-campaign-ii`.
