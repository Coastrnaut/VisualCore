# Contract: UA-F09 verification API

## VisualCoreExperience (pure)

```swift
public struct ExperienceOutcome: Sendable, Equatable, Codable {   // (new, release)
    public let code: String
    public init?(code: String)                                     // nil for an invalid code
}
extension ExperienceCore { public var outcome: ExperienceOutcome? { nil } }   // (new protocol requirement with default)
extension ExperienceEngine { public var outcome: ExperienceOutcome? { get } } // (new)
// ExperienceDiagnostics gains `public let outcome: ExperienceOutcome?` (new; decoded if present)

#if DEBUG || VISUALCORE_AUTOMATION
public struct ScenarioManifest: Sendable, Equatable, Codable {     // (new) schema 1, see data-model 2
    public static let schemaVersion = 1
    public static let standardNames: [String]                      // the nine
    public init(data: Data) throws(ScenarioManifestError)          // bounded: 4 MiB
}
public enum ScenarioManifestError: Error, Sendable, Equatable { case unreadable(String), newerSchema(Int), tooLarge(Int) }
public struct ContentRequirement: Sendable, Equatable { public init(fixtures:acceptance:faults:levels:) }
public enum ScenarioManifestValidator {                             // (new)
    public static func problems(_ manifest: ScenarioManifest, controls: [ExperienceControl],
                                content: ContentRequirement) -> [String]
}
public struct ScenarioObservation: Sendable, Equatable, Codable    // (new) data-model 3
public enum ScenarioEvaluator { public static func failures(_ spec: ScenarioSpec, _ observation: ScenarioObservation) -> [String] }
public enum FrameChecks { isNonBlank, isBlack, histogram, hasNonFinite, silhouette, classify }   // (new)
public struct FrameProbe: Sendable, Equatable { public let name: String; public let x: Double; public let y: Double; public let expected: String }
public struct ScenarioRequest: Sendable, Equatable {                // (new) data-model 5
    public static func parse(_ environment: [String: String]) -> Result<ScenarioRequest, ScenarioRequestError>?  // nil: no request
}
public struct EvidenceRecord: Sendable, Equatable, Codable         // (new) the app's part of schema 1
#endif
```

## VisualCoreExperienceHost (main actor)

```swift
extension ExperiencePresenter { public func probes(_ core: Core) -> [FrameProbe] { [] } }   // (new requirement, default empty)
// Experience gains `var frameProbes: [FrameProbe] { get }` (new); ExperienceShell forwards to its presenter.

#if DEBUG || VISUALCORE_AUTOMATION
@MainActor public final class ScenarioRunner {                     // (new)
    public init(session: ExperienceSession, storageRoot: URL)
    public func run(_ spec: ScenarioSpec, manifest: ScenarioManifest,
                    request: @MainActor (UInt64, ExperienceSnapshot?) -> ExperienceOpenRequest,
                    phase: ScenarioPhase, expectedDigest: String?) async -> ScenarioObservation
}
public enum ScenarioPhase: String, Sendable { case single, save, restore }
#endif
```

`FrameProbe` and `probes(_:)` are defined outside the `#if`: a presenter declares them in every build. They are
plain values, and only the runner reads them.

## Behaviour contracts

1. A scenario's actions go only through `Experience.handle(control:values:)`. The runner never calls the
   engine directly, never sets state, and counts what it sent; the observation records sent and handled counts.
2. Every runner wait has a limit: preparation uses the request's limit; a frame is up to 120 attempts; a whole
   scenario has the manifest's limit or 120 s.
3. The app exits with 0 (pass), 1 (fail) or 2 (error) only after the record file is written and synced.
4. A record is written even when the scenario fails or errors, unless the process crashes; the driver records a
   crash as a failure.
5. Nothing of sections 2 and 3 exists in a Release build without `VISUALCORE_AUTOMATION`.

## Tools

- `scripts/verify_experiences.py [--only ID…] [--skip ID…] [--scenario NAME…] [--runtime 27 26] [--kind phone]
  [--audits] [--self-test] [--dry-run] [--fresh] [--max-seconds N]`. Exit 0 when every step passed, 1 on a
  failure, 2 on bad input.
- `scripts/check_evidence.py <record.json…>` and `--self-test`. Exit 0 or 1.
- `scripts/xcodebuild_app.py --result-name NAME` (new option): writes `.autonomy/xcresults/NAME.xcresult`.
- `scripts/check_release_symbols.py` and `scripts/check_experience_symbols.py`: new names in their lists.
