# Research: R02-G01-01

- **R1 Package and platforms.** Decision: `Packages/ExperiencesRound02` with iOS 26 and macOS 15. Rationale: section 16
  names the package; macOS lets the pure Core run under `swift test` on the host and on CI in seconds, while later
  Experience targets (UIKit, GL) are built for the simulator. Alternatives: iOS only like ExperiencesCreative (every Core
  test would need a simulator run).
- **R2 Integer phase.** Decision: 4,096 units per turn, gates at sixteenths, steps of 16 and 256 units, Ω a power of two.
  Rationale: exact and identical everywhere; the period divides 4,096 so two periods are an integer number of ticks.
  Alternatives: Double radians with tolerance bands (the source allows it, but hashes of quantized state are preferred).
- **R3 Evaluate after each change.** Decision: the full two-period evaluation runs after every accepted move, undo or
  redo. Rationale: the outcome is a pure function of the controls; at most 98,304 integer steps.
- **R4 Refund on undo.** Decision: undo refunds the move. Rationale: Practice and Play both let the player think by
  trying; the allowance limits committed changes, matching "reversible mistakes" in Band 1. Alternatives: undo costs a move
  (punishes exploration).
- **R5 Fingerprints.** Decision: SHA-256 hex (`StableHash`) of fixed byte layouts. Rationale: the source asks for
  previous/next digests on every record; stale moves are detected exactly.
- **R6 Puzzle contract.** Decision: `AuroraLoomRules: PuzzleRules` over the six steps. Rationale: R02-G01-02 can certify
  levels with R02-F23's validator and generator without a second rules model.
