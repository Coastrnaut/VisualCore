# Data model: A07-P05

- **StreamingLevel**: behind (≥ 0), ahead (≥ 1), drawDistance (> 0, ≤ ahead × pieceLength), elementShare (0…1).
- **StreamingBudget**: levels (1…8, each value non-increasing with the level index), pieceLength (> 0);
  `level(_ index:)` clamps; `vertexTotal(level:perPieceVertices:)` = (behind + ahead + 1) × perPieceVertices;
  `fits(level:perPieceVertices:budget:)`.
- **JourneyAnnouncer**: interval 1.5 s on the presenter's clock, the sum of frame steps since setup (the host's frame
  time is wall clock; convergence T-A07-514); offering the last announced text again clears any pending text; lastText, lastTime, pending; `offer(_ text:, at time:) -> String?` returns the
  text to announce now or nil (keeps the latest pending), `tick(at:) -> String?` flushes the pending text when due.
- **OdysseyQuality**: the A07 `StreamingBudget` (levels of D2) and `starCount(level:)` = round(48 × elementShare).
