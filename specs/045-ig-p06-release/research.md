# Research: A05-P06

## D1 — Recovery seam
- **Decision**: internal `failNextDraw` on `GeometryPresenter` (Particle Universe pattern, feature 038 research D1).
- **Rationale**: proves the host's failure path without a release switch.

## D2 — Fixtures
- **Decision**: five files under `ExperienceTests/Fixtures/Library/`, copied into a temporary `ExperienceStorage`; the
  expected outcomes are the Phase 04 rules (missing format = unreadable).

## D3 — Interface chunk
- **Decision**: chunk `k2` = `IGControlsUITests`, `IGLibraryExportUITests`; candidate launch arguments as `PUSupport`.
- **Rationale**: the existing build-once, two-clone chunk runner; each chunk stays under the ten-minute limit.

## D4 — Release documents
- **Decision**: `release.json` (schema 1) with requiredDocs, checklist and `copyCheck` (store listing + controls and
  presenter); `release_check.py` picks it up automatically (`experience-release-a05`, `copy-claims-a05`).
