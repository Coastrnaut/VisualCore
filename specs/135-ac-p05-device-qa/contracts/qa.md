# Contract: still work and QA (A18-P05)

- **`CachedScene`:**
  - with `passThrough` false and a fixed key, 120 renders give one child draw and byte-identical frames;
  - a key change gives one more draw, and the frame equals the child's own frame;
  - resize and a repeated setup give one more draw each and the same frame at the same size;
  - with `passThrough` true, every render draws the child;
  - teardown leaves no GPU object.
- **Presenter:**
  - motion off and seconds off: 120 frames at a fixed instant give one background draw;
  - a palette change gives one more;
  - motion on gives 120 draws;
  - seconds on with motion off is not still (pass-through).
- **Campaign:** `device-campaign.md` has rows AC-D1 to AC-D10, each with device, procedure, threshold and
  "pending device campaign".
- **Interface (chunk `z2`):**
  - the clock opens with its time label;
  - night mode and reduce motion set from the controls are kept after a relaunch.
