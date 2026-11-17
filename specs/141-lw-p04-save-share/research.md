# Research: A19-P04 (feature 141)

- **D1 Share through the system sheet (Q1):**
  - **Decision:** `ShareLink` with a `Transferable` file.
  - **Rationale:** the person chooses the destination, and the add-only string covers "Save Image".
  - **Alternative:** PhotoKit add-only authorization. Rejected (A19-P00 clarification 4).
- **D2 Encode off the main actor (Q2):**
  - **Decision:** a detached task for the encode and the read-back.
  - **Rationale:** both are CPU-only, and the render must stay on the main actor.
  - **Alternative:** everything on the main actor. Rejected, because the interface would stall for large sizes.
- **D3 History in the core (Q3):**
  - **Decision:** a pure versioned model stored by the experience.
  - **Rationale:** testable without the GPU; the pattern of A18's favourites.
  - **Alternative:** keeping exported files as history. Rejected: files stay temporary, and history is metadata only.
- **D4 Release steps now (Q1):** `app-usage-descriptions` needs a Release build, so `app-release-build` runs in this
  phase too.
