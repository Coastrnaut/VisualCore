# Research: A19-P03 (feature 140)

- **D1 Custom colours as an override (Q1):** the preset index stays, and four colours may override it.
  - **Rationale:** the smallest schema change; a reset is "clear the override".
  - **Alternative:** user-defined presets in a library. Deferred, because it needs storage and naming (A19-P04 brings
    the history).
- **D2 Schema examples now (Q1, lesson of X-A17):** schema-1 examples are stored and registered in the phase that
  raises the schema.
- **D3 Notice in the core (Q2):** pure text from the planner's refusal, so it is tested without the GPU and with the
  numbers exactly.
- **D4 Help as data (Q4):** the sections are pure strings in the core, scanned by both the platform and help scans.
  The view only lays them out.
- **D5 Announcements (Q5):** through `ExperienceFeedback.announce`, which already rate-limits with
  `AnnouncementPlanner`. A test injects a recording sink.
