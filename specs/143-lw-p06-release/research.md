# Research: A19-P06 (feature 143)

- **D1 Statuses (clarification Q1):** the release checker's own statuses, as in A18-P06. Decision: verified,
  pending-campaign-ii (LW-D1 … LW-D8), owner-action. Alternative: a new status for simulator-only results; rejected,
  because the checker would refuse it.
- **D2 Refused words (Q2):** the wallpaper-setting and live-wallpaper wording is refused because no public API sets a
  wallpaper and an export is a still; "video" because the short loop is a no-go for 0.1 (video-decision.md);
  "unlimited", "8k" and "any size" because exports are capped by the device and 8192; "lossless" because JPEG and HEIC
  are lossy. The shared denylist already refuses measured numbers and frame-rate phrases. `share` is allowed because
  the file really goes to the share sheet. Alternative: allow `sharing` too; rejected, the copy does not need it.
- **D3 Source scan (Q3):** the A18 list plus `import Photos` and `PhotosUI`; the idle timer is refused everywhere
  (A19 never keeps the screen awake). The existing A19-P04 Photos scan stays.
- **D4 Recovery and samples (Q4):** as A18's, applied to `history.json` and the snapshot schemas 1–2.
  Alternative: inject the failure through a shader error; rejected, a compile error is setup-time and not repeatable.
- **D5 Interface (Q5):** one more test class in chunk `a3`; clearing the history is the only stored-data action of the
  interface.
