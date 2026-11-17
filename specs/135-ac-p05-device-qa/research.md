# Research: A18-P05 (feature 135)

- **D1 The cache in VisualCoreRendering (clarification Q1):** experiences may not call the graphics API, and the cache
  is generic (any still full-screen scene).
  - **Alternative:** skipping draws in the host. Rejected, because the framebuffer must still be presented every
    frame.
- **D2 The still rule (Q2):** motion off or reduced, seconds off and no fade. The key covers everything the picture
  depends on, so a stale picture can never be shown.
- **D3 The campaign (Q3):** ten rows modelled on Interactive Anatomy's `device-campaign.md`, for the order D1 → D2 →
  D3. D3 is not updated from iPadOS 26.5.
- **D4 Interface tests (Q4):** a serial chunk `z2`, launched like `IASupport`.
