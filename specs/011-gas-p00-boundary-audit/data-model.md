# Data model: app VisualCore contract (schema 1)

`docs/apps/<slug>/visualcore-contract.json`:

```json
{
  "schema": 1, "app": "generative-art-studio", "gate": "A01-P00", "date": "YYYY-MM-DD",
  "inventory": [ { "area": "...", "description": "...", "paths": ["..."], "owner": "..." } ],
  "matrix": [ { "id": "M01", "capability": "...", "source": "brainstorm|v0.1 feature NN",
                "status": "available|requires adaptation|upstream gap",
                "evidence": [ { "file": "...", "symbol": "Type[.member]", "product": "VisualCoreX", "public": true } ],
                "example": { "file": "...", "symbol": "..." }, "notes": "..." } ],
  "gaps": [ { "id": "G-…", "matrix": ["M05"], "kind": "adaptation|upstream",
              "owner": "VisualCore:<Module>|app-local", "justification": "...", "phase": 1, "test": "..." } ],
  "traceability": [ { "item": "v0.1 feature 01 | journey 1 | brainstorm", "matrix": ["M01"], "phases": [2] } ],
  "negative": [ { "rule": "...", "source": "..." } ],
  "decision": { "result": "go|stop", "reasons": ["..."], "blockers": [] }
}
```

Validation rules (checker):
- `status` and `kind` come from the enumerations above.
- Every `available` or `requires adaptation` row has ≥ 1 evidence item. An `upstream gap` row cites the placeholder
  or the closest existing symbol, or has `evidence: []` with a non-empty `notes` reason (analyze A1).
- Evidence files MUST NOT be under `Tests/`, `External/` or `Harnesses/`: evidence is shippable VisualCore API, and
  ProjectM-only capabilities count as unavailable. An `example` may be a test, sample or harness (analyze E1).
- Every evidence and example file exists, and its symbol is declared in it (with `public` when `public: true`).
- `product` must be a library product declared in a `Packages/*/Package.swift`.
- Every non-`available` row is referenced by ≥ 1 gap.
- Every gap names an owner. `app-local` requires a non-empty justification.
- `phase` is 1–6.
- Traceability covers v0.1 features 01–06 and journeys 1–3.
- `decision.result` is `go` only when `blockers` is empty.
- Sizes are bounded: ≤ 200 rows per list, strings ≤ 2,000 characters. Unknown keys are rejected.
