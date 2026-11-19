# Research: A23-P01 (feature 166)

- **D1 Types (clarification Q1):** four value types with exact matching. Alternatives considered: implicit
  scalar-to-colour and time-to-scalar conversions (rejected: the manual's fixture 2 asks that colour never feeds a
  scalar input without an explicit converter, and implicit rules make the refusal text unclear). Two outputs on
  `constant` give both a scalar and a colour source without an eighth kind.
- **D2 Limits (Q2):** 32 nodes and 64 connections keep the version 0.1 non-goal ("no desktop-class editor with
  hundreds of nodes") and make every check trivially bounded. Identities 1…9,999 and positions within ±4,096 points
  bound the file; the numbers are checked on devices in the campaign (contract D4a).
- **D3 File (Q3):** an app-local envelope (kind, version, body) with canonical JSON, as Shader Studio's is. The body
  goes through `MigrationChain` as a JSON object before decoding, so a schema 2 adds one step and old shapes need no
  old Swift types. It is stored through `ExperienceStorage` later (A23-P04). The fingerprint uses `DigestBuilder`,
  because a digest of typed fields does not depend on JSON formatting.
- **D4 Order and cycle path (Q4):** Kahn's algorithm with a sorted ready set gives a deterministic order in
  O((n + e) log n). Every node left after Kahn has an incoming connection from another node left, so walking backwards
  along incoming connections always reaches a repeated node: the walk always ends on a loop and is stable. The private
  Kahn order of `EffectGraphValidator` is not reused (contract research D5).
- **D5 Proof (Q5):** a scene on `RenderHost(scene:)` checks every fixture inside `setup` and `render` and compares
  `ResourceRegistry.stats` before and after, as the Shader Studio stress tests read levels. Nothing is drawn.
