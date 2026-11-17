# Research: A21-P06 (feature 157)

- **D1 Statuses (clarification Q1):** the release checker's three statuses, as A20. Device rows name AU-D1 … AU-D8.
- **D2 Claims (Q2):** an experience scan on top of the shared denylist, because the shared list knows nothing of
  forecasts, sleep or always-on screens. `copyCheck.allow` is empty: Aurora shares nothing.
- **D3 Sources (Q3):** the A20 list plus `import CoreLocation`. `AVFAudio` is allowed: the loop uses the output only,
  and `inputNode` and `installTap` are refused.
- **D4 Recovery (Q4):** a one-shot `failNextDraw` seam, after A20. Alternative: `breakShaders` (rejected: it proves
  the fallback, not a failure).
- **D5 Samples (Q4):** generated once by a throwaway test that calls the real encoders, then committed (the A20
  lesson), so the digests are the code's own.
- **D6 Interface (Q5):** `AUReleaseUITests` in `c3`; first-session defaults only.
