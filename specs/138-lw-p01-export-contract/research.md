# Research: A19-P01 (feature 138)

- **D1 Core only (clarification Q1):**
  - **Decision:** pure `LivingWallpapersCore` with its tests.
  - **Rationale:** the gate is domain tests plus a validated export contract, and drawing is A19-P02.
  - **Alternative:** add the experience now. Rejected, because it would bring an interface without scenes.
- **D2 Fallback through `ExportGeometry` (Q3):**
  - **Decision:** a template that fits keeps its exact size. One that does not uses `ExportGeometry(maxEdge:maxPixels:)`
    with `size(longEdge:aspect:)` at the template's aspect (even edges).
  - **Rationale:** the rules are reused, and "largest fitting" is its documented behaviour.
  - **Alternative:** an own fitting rule. Rejected under Principle II.
- **D3 Read-back inspection:**
  - **Decision:** the core reads a written file with ImageIO (`CGImageSourceCreateWithData`, the pixel width and
    height properties, and the image's colour space name), and compares the result with the plan.
  - **Rationale:** the claim is about the file, not the request.
  - **Alternative:** trust the encoder. Rejected, because the manual requires verification.
- **D4 Fixture through the real encoder:**
  - **Decision:** the tests build a solid-colour `StillImage` at the planned size and encode it with
    `StillImageEncoder.pngData`, then inspect it.
  - **Rationale:** this is the production encoder, on the CPU.
  - **Alternative:** synthesize a PNG in the test. Rejected, because it would prove nothing about the export path.
- **D5 Project file (Q4):**
  - **Decision:** its own envelope `{kind, schemaVersion, project}`, as `ClockPreferences` has, with the refusals of
    clarification Q4.
  - **Rationale:** flat-file storage, and a document smaller than `DocumentStore` assumes.
  - **Alternative:** `DocumentStore`. Rejected, because it needs a folder.
- **D6 Video (Q5):** no-go, recorded, and guarded by `scan-platform-claims.sh`.
