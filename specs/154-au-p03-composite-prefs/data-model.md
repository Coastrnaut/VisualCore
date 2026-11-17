# Data Model: A21-P03 (feature 154)

- **SkyPreferences** (schema 1, kind `a21.preferences`, experience value `prefs.v1`, ≤ 4,096 bytes): `preset`
  (catalog id), `hue` −0.5…0.5, `speed` 0…2, `turbulence` 0…1, `ribbons` 1…4, `stars` 0…400, `clouds` 0…1, `limit`
  0.2…0.72, `soundOn` (default false), `volume` 0…1 (default 0.5). Codes: `damaged`, `newer-version`, `out-of-range`.
  Defaults: preset `polar-night` with its scene, hue 0, limit 0.6, sound off, volume 0.5.
- **SkyTransition:** a `CrossfadeScene` of the outgoing and incoming skies; progress over 2.0 s of frame time,
  smoothstep; a new choice mid-change calls `replaceIncoming`; immediate under Reduce Motion.
- **Messages:** "Your saved choices could not be read, so the default sky is shown." (damaged, newer, out of range);
  "Your choices could not be saved." (a failed save, once).
