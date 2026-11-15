# Research: A13-P06 (feature 101)

## D1 — Privacy note
- **Decision**: `docs/apps/light-maze/privacy-and-credits.md` lists `progress.json` in the experience's folder and the
  app's session state (level, orientations, selection, moves), no personal data, nothing sent, no permission, deletion
  by the app's data reset or removing the app; credits: 20 levels by "VisualCore project" under MIT
  (`content-licenses.md`), the success sweep made in code, no third-party content.
- **Precedent**: `docs/apps/tiny-worlds/privacy-and-credits.md`.

## D2 — Copy and claims
- **Decision**: `store-listing.md` with a claim → test table; `scan-claims-release.sh` refuses the clarified words in the
  store text and `MazeControls.swift`/`MazePresenter.swift` and checks every named test exists; the shared copy check
  runs from `release.json`.

## D3 — Recovery and samples
- **Decision**: `failNextDraw` as Tiny Worlds'; samples: valid = the bytes `Progress.encoded()` writes after solving
  level 1; newer = schema 2; damaged = not JSON; truncated = the valid bytes cut in half.

## D4 — Interface tests
- **Decision**: `LMSupport` modelled on `TWSupport` (launch `-vcCandidates -openExperience a13.light-maze`, element
  lookup by `experience.a13.light-maze.<name>`); `LMLevelUITests` (Level menu → level 2; back to level 1; select next,
  turn → status solved; undo → not solved) and `LMHelpUITests` (Hint → message names a mirror; Describe → message
  starts "Level 1, First light"); serial chunk `u2`.

## D5 — Release checks
- **Decision**: `release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking
  app-licenses app-usage-descriptions experience-release-a13 copy-claims-a13` (names checked at implementation from
  `--list`).
