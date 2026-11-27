# API contract: R02-G21-07 (BinaryGardensCore additions)

```swift
extension BinaryGardensProgress.Result {                    // on feature 505's result (actionsSpent, stars)
    public let trace: [BinaryGardensAction]                 // ring, phase, luminosity, tilt actions; the last is .run
    public let verified: Bool }
extension BinaryGardensProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: BinaryGardensMode = .campaign,
                                trace: [BinaryGardensAction]) -> Bool   // verified result; practice, replay: false
    public mutating func drop(level: Int) }                  // reconciliation only; the frontier is kept
extension BinaryGardensMode { case replay(level: Int) }      // Codable as feature 505's other cases
public enum BinaryGardensReconciliation {
    public static let maxTraceLength: Int                   // 64
    public static func netTrace(_ records: [BinaryGardensRecord]) -> [BinaryGardensAction]
    public static func verifies(level: Int, result: BinaryGardensProgress.Result) -> Bool
    public static func reconcile(_ progress: BinaryGardensProgress) -> (progress: BinaryGardensProgress, dropped: Int)
}
extension BinaryGardensExperienceRule {
    public static let noReplay: String                      // "r02-g21.no-replay"
    public static let replayEnd: String                     // "r02-g21.replay-end"
    public static let replay: String }                      // "r02-g21.replay"
// BinaryGardensExperienceCore: schemaVersion 3; digestDomain "r02-g21.binary-gardens.v3" (level, play fingerprint,
// progress with traces, mode); migrations 1 → 2 (feature 505) → 3 (`migratedToSchemaThree(_:)`); actionIDs gain
// "replay.start" [1…100], "replay.step", "replay.stop", "settings.sound" [0…1] (`soundRange`; `r02-g21.not-whole`
// for a fractional value); `public private(set) var reconciliationDropped: Int` (not digested, not in ==);
// `public private(set) var soundOn: Bool` (snapshot key "sound", in ==, not digested; off at opening, reset and
// migration); `static let replayControls: Set<String>`; a win records `netTrace(play.records)` outside replay and
// practice; restore reconciles, checks a saved replay's prefix (`damaged` otherwise) and returns a replay whose result
// is gone or unverified to campaign at its level or the frontier.
// BinaryGardensFeedbackPlan (feature 506): refusal words "There is no saved solution to replay for this level.",
// "The replay is over.", "Stop the replay first." for the three codes; a replay step planned like the action it
// applies; replay start and stop like a fresh opening (mode "replay" or "campaign"); a replayed win claims no stars;
// modeName(.replay) == "replay".
```

Experience (`BinaryGardensExperience`, internal): `BinaryGardensPresenter.startReplay(port:)`, `stepReplay(port:)`,
`stopReplay(port:)`, `saveSound(on:port:)` (sends `settings.sound`), `droppedText(_:)` ("n saved results could not be
checked and were removed.", "1 saved result could not be checked and was removed."), announced once per presenter as
`state`; the mirror's `replayAvailable`, `replaying`, `replayPosition`, `replayLength` and `soundOn` (from the core);
refused replay actions join 504's `refusalLog` by code. `BinaryGardensControls` identifiers `replay`, `replay-step`,
`replay-stop`, `replay-position` with labels and values ("Replay: action k of n").
