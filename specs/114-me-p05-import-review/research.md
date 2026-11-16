# Research: A15-P05 (feature 114)

## D1 — Import as actions
- **Decision**: `import.begin [n]`, `import.atom [Z, x, y, z]` × n, `import.end []`, then `molecule.select [5]`; the
  engine re-checks every limit; refusals `a15.invalid-import` (clarification Q1).
- **Rationale**: actions carry numbers only; replaying a sequence is how `AquariumLibrary.open` rebuilds a document;
  the engine stays deterministic and the import is in snapshots and digests.
- **Alternatives**: an injected molecule provider outside the state (rejected: replays and snapshots would miss it);
  a presenter-only preview (rejected: two drawing paths, no picking or panel parity).

## D2 — Size and messages
- **Decision**: refuse above 65,536 bytes from the file size before reading; fixed sentences per reason (clarification Q2).

## D3 — Storage and title
- **Decision**: `import.xyz`, one slot; title from the file name, sanitized, ≤ 40 characters; recent id `imported`
  (clarification Q3).

## D4 — Fuzz corpus
- **Decision**: 2,000 seeded mutations of the library molecules' XYZ text and the refusal fixtures through the whole
  path (clarification Q4). **Alternatives**: random bytes only (rejected: rarely reaches the parser's later rules).

## D5 — Review
- **Decision**: generated `data-review.md` compared byte for byte; a domain claim-word test over every shown
  sentence; the shared copy-claims check over the experience sources (clarification Q5).

## D6 — Leak fixture
- **Decision**: ten rounds of choosing every molecule, importing and restoring the saved snapshot on the off-screen
  host; `ResourceLedger` live counts and bytes equal the first round's; leaked 0, following `MoleculeSessionTests`.
