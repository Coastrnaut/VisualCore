# Contract: UA-F07 framework and app additions

## VisualCoreExperienceHost (main actor)

```swift
extension ExperiencePresenter {
    /// A pointer event on the canvas (feature 193): the presenter turns it into domain actions with positions
    /// normalized to the view and sends them through `port`. Default: nothing.
    public func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {}   // (new requirement)
}
// Experience gains `func handlePointer(_ event: PointerEvent, viewSize: Vec2)` (new); ExperienceShell forwards it to
// its presenter with its port. ExperienceSession sets `renderHost.pointerHandler` while an experience is open and
// clears it at every close (new behaviour, no new public symbol).
```

`PointerEvent` and `Vec2` are the existing pure types of `VisualCoreScenes` and `VisualCoreMath`. The host module
gains a dependency on `VisualCoreScenes` if it does not have one.

## App

```swift
enum ExperienceRegistry {
    static let all: [ExperienceRegistration]          // existing; available experiences
    static let candidates: [ExperienceRegistration]   // (new) adopted before their X gate (A01–A04)
}
```

Debug launch argument `-vcCandidates`: in debug builds the fixture catalog makes the candidates' entries available
and registers them. It is used by the ported interface tests.

## Tools

- `scripts/check_test_map.py --map specs/193-ua-f07-legacy-adoption/test-map.csv --old Apps/<App>/Tests/UI
  --new Apps/VisualCore/Tests/UI/<Name> [--log <app test log>]`: exit 1 when an old method is missing from the map,
  when a mapped new method does not exist, or (with `--log`) when it did not pass.
- `scripts/check_app_contract.py`: a cited path that no longer exists resolves through `Catalog/path-map.json`.

## Behaviour contracts

1. Adapters do not change Core types; each difference from the standalone app is listed in the adapter's file
   header and in research.md.
2. Time in a core advances only in `update(step:)`; the presenter draws from the core and never steps it.
3. A pointer event never changes state except through an action the port accepts.
