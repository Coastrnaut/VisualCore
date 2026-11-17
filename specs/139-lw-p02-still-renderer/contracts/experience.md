# Contract: Living Wallpapers experience (A19-P02)

- **Actions:** every action is validated, and equal actions give equal digests. The snapshot round-trips. The
  manifest validates with the nine standard scenarios and five fixtures.
- **Scenes:** each of the four at both levels draws a non-blank picture, and equal state and time give identical
  pixels.
- **Crop frame:** for all nine templates in both orientations, the frame is inside the canvas, with the template
  aspect within one point.
- **Export:**
  - each available format exports at a fitting template size and verifies;
  - after a cancel after render, a cancel after encode, an oversize failure and a retry, the host's live counts and
    the folder's file count equal the starting values;
  - the live picture still renders afterwards.
- **Isolation:** no GL call and no wallpaper call in the experience; `scan-platform-claims.sh` passes.
