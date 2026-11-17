# Research: A19-P02 (feature 139)

- **D1 Encoder in VisualCore (Q1):**
  - **Decision:** `StillImageFormat` and `data(_:format:quality:)`, additive.
  - **Rationale:** every exporter (A01, A02, A03, A05, A16) can use it.
  - **Alternative:** an experience-local encoder. Rejected under Principle II.
- **D2 No new error case:** an unavailable format throws `.encoding`. Adding a case to `OffscreenRenderError` would
  break exhaustive switches; the experience gives its own named reason before rendering.
- **D3 Timed still (Q2):**
  - **Decision:** an overload, plus `ExperienceStillRenderer(timed:)`.
  - **Rationale:** existing callers stay at time 0, unchanged.
  - **Alternative:** change the default. Rejected, because it would change A01–A16 exports.
- **D4 Scenes (Q3):**
  - **Decision:** inline fragment sources, one `FullScreenShaderScene` at a time.
  - **Rationale:** A18's pattern, one draw.
  - **Alternative:** a crossfade between scenes. Deferred: the editor phase may add one.
- **D5 Crop geometry in the core (Q4):** pure and testable without the GPU; the overlay is native.
- **D6 Export attempt (Q5):** synchronous on the main actor, a cancel flag between steps, and a temporary folder
  owned by the attempt. Progress for long exports comes with G-EXPORTJOB (A19-P04).
- **D7 As built:** the export limit comes from the context's maximum texture size (data-model "As built"), and the
  host's own check stays the last word. The retry uses the offered plan directly, so an export never re-plans
  against the same limit that refused it.
