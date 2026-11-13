# API contract: R02-F26 (additive)

VisualCoreScenes: `GestureDeclaration`, `GestureOutcome`, `GestureArbiter` (`init(_ declarations:)`,
`mutating func handle(_ event: PointerEvent) -> [GestureOutcome]`, `mutating func cancelAll() -> [GestureOutcome]`).
VisualCoreSimulation: `Announcement`, `AnnouncementPlanner`, `HapticEvent`, `HapticPlanner`, `StateSign`,
`stateSignProblems(_:)`.
VisualCoreExperience: `ShellPreferences.haptics`, `GestureAlternatives.missing(gesture:native:)`.
VisualCoreUI: `HapticSink`, `AnnouncementSink`, `SystemHapticSink`, `SystemAnnouncementSink`.
VisualCoreExperienceHost: `ExperiencePresenter.gestureActions`, `.nativeActions` (defaults empty); session feedback and
announcement entry points.
