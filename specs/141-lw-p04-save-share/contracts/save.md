# Contract: Living Wallpapers save and share (A19-P04)

- **Share:**
  - after a written export, the share item is the written file with the plan's content type and the documented
    name;
  - with no written file there is no share item;
  - `scan-photos.sh` passes;
  - the registration declares `photo-library-add`;
  - `app-usage-descriptions` passes on a Release build.
- **Job:**
  - progress is 0.2, 0.4, 0.7, 0.85 and 1.0 on success;
  - a cancel after each step leaves 0 files and the host's live counts unchanged, and the live picture renders;
  - a failure names its reason, and `retry` uses the offered plan after does-not-fit.
- **History:**
  - newest first, bounded to 20;
  - an exact round trip;
  - a damaged or newer file gives an empty history with one problem;
  - written after each export with the injected clock's time;
  - `cleared()` empties it.
- **Short loop:** `scan-platform-claims.sh` passes, and `video-decision.md` is unchanged.
