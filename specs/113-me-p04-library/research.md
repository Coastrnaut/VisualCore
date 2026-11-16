# Research: A15-P04 (feature 113)

## D1 — Documents and stores
- **Decision**: two schema-1 documents with sorted keys and byte caps, codecs refusing `damaged`, `oversized`,
  `newer-version`, `out-of-range`; stores following `ViewStore` (missing / refused / unreadable; load never writes;
  in-memory without storage) (clarifications Q1–Q3).
- **Alternatives**: putting the recent list into the engine state (rejected: it would change digests and replays).

## D2 — Recent list rule
- **Decision**: newest first, unique, cap 8, unknown ids dropped on read; the first molecule counts (clarification Q1).

## D3 — Label mode
- **Decision**: all / selected / none, default all; the ring stays (clarification Q2).

## D4 — Controls
- **Decision**: Library section with attributions, Recent menu, Labels picker (clarification Q4).

## D5 — Determinism fixture
- **Decision**: five seeded shuffles per molecule; mapped-back pairs equal; all inferred and single (clarification Q5).
