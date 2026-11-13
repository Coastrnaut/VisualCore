# Particle Universe — release dossier (history)

Particle Universe is now the experience `a04.particle-universe` of the one VisualCore app (ADR-0009; feature 193, UA-F07). Its standalone app target stays until X-A04 (feature 193, FR-U07-043), compiling the sources that moved to `Packages/ExperiencesCreative/ParticleUniverse`. The store listing,
release checklist and other files of this dossier describe the standalone app that was never shipped. They are kept
unchanged as history; the one app's listing, privacy manifest and release records supersede them.

## Scene editor and saved scenes (feature 036, A04-P04)

In the one app, the controls keep a library of named scenes in the experience's own storage area (`scene-<id>.json`,
format version 2; version 1 scenes upgrade on opening; damaged, non-finite or newer files are refused, counted and
kept). Saving under an existing name keeps both with a numbered suffix; renaming onto an existing name is refused.
Opening a scene sends a short series of logged actions (`scene.begin`, `emitter.define`, `force.define`,
`look.define`), so a replay reaches the same scene; the seed, particle limit, time scale and scene forces stay as they
are. The selected emitter moves with four direction buttons (`emitter.move`, 50 points per press, within ±500).
