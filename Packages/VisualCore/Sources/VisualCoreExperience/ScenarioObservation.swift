// ScenarioObservation — feature 195 T-U09-007 (FR-U09-003, FR-U09-010, FR-U09-052; data-model section 3). What the
// verification runner observed while it played one scenario, and the pure comparison of that observation with the
// scenario's expectations. Compiles only under DEBUG or VISUALCORE_AUTOMATION.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// What the runner observed while it played one scenario. In JSON the seed is written as decimal text.
public struct ScenarioObservation: Sendable, Equatable, Codable {
    /// The name of the scenario played.
    public let scenario: String
    /// The seed the experience was prepared with.
    public let seed: UInt64
    /// One observation per action sent, in order.
    public let steps: [StepObservation]
    /// The state digests observed at the points the runner reads them.
    public let digests: ObservedDigests
    /// The outcome code the experience reported at the end; nil when it reported none.
    public let outcome: String?
    /// The frame read back at the end; nil when none was read.
    public let frame: FrameObservation?
    /// How long the stages of the run took.
    public let timing: ScenarioTiming
    /// The resources in use at the end of the run.
    public let resources: ScenarioResources
    /// The actions the runner sent through the experience.
    public let actionsSent: Int
    /// The actions the experience reported as handled.
    public let actionsHandled: Int
    /// Failures the runner found itself (time limits, errors, leaks); each is a readable text.
    public let failures: [String]

    /// Creates an observation.
    public init(scenario: String, seed: UInt64, steps: [StepObservation] = [], digests: ObservedDigests = ObservedDigests(),
                outcome: String? = nil, frame: FrameObservation? = nil, timing: ScenarioTiming = ScenarioTiming(),
                resources: ScenarioResources = ScenarioResources(), actionsSent: Int = 0, actionsHandled: Int = 0,
                failures: [String] = []) {
        self.scenario = scenario
        self.seed = seed
        self.steps = steps
        self.digests = digests
        self.outcome = outcome
        self.frame = frame
        self.timing = timing
        self.resources = resources
        self.actionsSent = actionsSent
        self.actionsHandled = actionsHandled
        self.failures = failures
    }

    private enum CodingKeys: String, CodingKey {
        case scenario, seed, steps, digests, outcome, frame, timing, resources, actionsSent, actionsHandled, failures
    }

    /// Decodes an observation; the seed is read from decimal text.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scenario = try c.decode(String.self, forKey: .scenario)
        let text = try c.decode(String.self, forKey: .seed)
        guard let value = UInt64(text), String(value) == text else {
            throw DecodingError.dataCorruptedError(forKey: .seed, in: c,
                                                   debugDescription: "the seed is not the decimal text of a 64-bit number")
        }
        seed = value
        steps = try c.decode([StepObservation].self, forKey: .steps)
        digests = try c.decode(ObservedDigests.self, forKey: .digests)
        outcome = try c.decodeIfPresent(String.self, forKey: .outcome)
        frame = try c.decodeIfPresent(FrameObservation.self, forKey: .frame)
        timing = try c.decode(ScenarioTiming.self, forKey: .timing)
        resources = try c.decode(ScenarioResources.self, forKey: .resources)
        actionsSent = try c.decode(Int.self, forKey: .actionsSent)
        actionsHandled = try c.decode(Int.self, forKey: .actionsHandled)
        failures = try c.decode([String].self, forKey: .failures)
    }

    /// Encodes the observation; the seed is written as decimal text and absent items are left out.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scenario, forKey: .scenario)
        try c.encode(String(seed), forKey: .seed)
        try c.encode(steps, forKey: .steps)
        try c.encode(digests, forKey: .digests)
        try c.encodeIfPresent(outcome, forKey: .outcome)
        try c.encodeIfPresent(frame, forKey: .frame)
        try c.encode(timing, forKey: .timing)
        try c.encode(resources, forKey: .resources)
        try c.encode(actionsSent, forKey: .actionsSent)
        try c.encode(actionsHandled, forKey: .actionsHandled)
        try c.encode(failures, forKey: .failures)
    }
}

/// What the runner observed for one action it sent.
public struct StepObservation: Sendable, Equatable, Codable {
    /// The control the action used.
    public let control: String
    /// The values the action carried.
    public let values: [Double]
    /// The answer: `accepted` or the rejection code.
    public let result: String
    /// The state digest right after the action; nil when it could not be read.
    public let digest: String?

    /// Creates a step observation.
    public init(control: String, values: [Double] = [], result: String, digest: String? = nil) {
        self.control = control
        self.values = values
        self.result = result
        self.digest = digest
    }
}

/// The state digests the runner observed; each is nil when it was not read.
public struct ObservedDigests: Sendable, Equatable, Codable {
    /// The digest right after preparation.
    public let initial: String?
    /// The digest at the end of the run.
    public let final: String?
    /// The digest right after a snapshot was restored.
    public let afterRestore: String?
    /// The digest right after a reset.
    public let afterReset: String?

    /// Creates the digests; all are nil by default.
    public init(initial: String? = nil, final: String? = nil, afterRestore: String? = nil, afterReset: String? = nil) {
        self.initial = initial
        self.final = final
        self.afterRestore = afterRestore
        self.afterReset = afterReset
    }
}

/// A frame the runner read back.
public struct FrameObservation: Sendable, Equatable, Codable {
    /// The width in pixels.
    public let width: Int
    /// The height in pixels.
    public let height: Int
    /// The SHA-256 of the RGBA bytes as 64 lower-case hexadecimal digits.
    public let sha256: String
    /// Whether the frame is not blank (more than one colour and enough luminance spread).
    public let nonBlank: Bool
    /// The class each probe showed (probe name → `dark`, `light`, `red`, `green`, `blue` or `other`).
    public let probes: [String: String]

    /// Creates a frame observation.
    public init(width: Int, height: Int, sha256: String, nonBlank: Bool, probes: [String: String] = [:]) {
        self.width = width
        self.height = height
        self.sha256 = sha256
        self.nonBlank = nonBlank
        self.probes = probes
    }
}

/// How long the stages of a run took, in seconds, and how many GPU programs were compiled.
public struct ScenarioTiming: Sendable, Equatable, Codable {
    /// Seconds from the start of preparation to its end.
    public let preparation: Double
    /// Seconds the presenter took to set up.
    public let setup: Double
    /// Seconds from the open request to the first presented frame.
    public let firstPresent: Double
    /// The GPU programs compiled during the run.
    public let programsCompiled: Int

    /// Creates a timing; everything is 0 by default.
    public init(preparation: Double = 0, setup: Double = 0, firstPresent: Double = 0, programsCompiled: Int = 0) {
        self.preparation = preparation
        self.setup = setup
        self.firstPresent = firstPresent
        self.programsCompiled = programsCompiled
    }
}

/// The resources in use at the end of a run.
public struct ScenarioResources: Sendable, Equatable, Codable {
    /// The process memory footprint in bytes.
    public let footprint: Int
    /// The bytes of GPU objects the experience holds.
    public let gpuBytes: Int
    /// The GPU objects still live.
    public let live: Int
    /// The GPU objects leaked.
    public let leaked: Int

    /// Creates a resource reading; everything is 0 by default.
    public init(footprint: Int = 0, gpuBytes: Int = 0, live: Int = 0, leaked: Int = 0) {
        self.footprint = footprint
        self.gpuBytes = gpuBytes
        self.live = live
        self.leaked = leaked
    }
}

/// The comparison of an observation with the expectations of its scenario.
public enum ScenarioEvaluator {
    /// Returns every failure of `observation` against `spec`; an empty list means the scenario passed.
    ///
    /// Steps are compared by the order of the scenario's actions: the i-th entry with an action is compared with the
    /// i-th step observation, and messages count steps from 1. A missing observation for an expected item is a
    /// failure. Sent and handled counts that differ fail as `bypass`. The observation's own failures are appended
    /// unchanged at the end.
    public static func failures(_ spec: ScenarioSpec, _ observation: ScenarioObservation) -> [String] {
        var failures: [String] = []
        if observation.scenario != spec.name {
            failures.append("scenario: expected \(spec.name), got \(observation.scenario)")
        }
        if observation.seed != spec.seed {
            failures.append("seed: expected \(spec.seed), got \(observation.seed)")
        }

        let actions = spec.entries.filter { $0.action != nil }
        for (index, entry) in actions.enumerated() {
            let number = index + 1
            let step = index < observation.steps.count ? observation.steps[index] : nil
            if let action = entry.action, let step, step.control != action.control {
                failures.append("step \(number): expected control \(action.control), got \(step.control)")
            }
            if let expected = entry.result {
                let got = step.map { describe($0.result) } ?? "no observation"
                if step?.result != expected {
                    failures.append("step \(number): expected \(describe(expected)), got \(got)")
                }
            }
            if let expected = entry.digest, step?.digest != expected {
                failures.append("step \(number) digest: expected \(expected), got \(step?.digest ?? "none")")
            }
        }

        let digests = observation.digests
        if let expected = spec.expect.initialDigest, digests.initial != expected {
            failures.append("initial digest: expected \(expected), got \(digests.initial ?? "none")")
        }
        if let expected = spec.expect.finalDigest {
            if digests.final != expected {
                failures.append("final digest: expected \(expected), got \(digests.final ?? "none")")
            }
            if let restored = digests.afterRestore, restored != expected {
                failures.append("after-restore digest: expected \(expected), got \(restored)")
            }
        }
        if spec.expect.resetDigest == true {
            if let initial = digests.initial {
                if digests.afterReset != initial {
                    failures.append("after-reset digest: expected \(initial), got \(digests.afterReset ?? "none")")
                }
            } else {
                failures.append("after-reset digest: no initial digest observed")
            }
        }
        if let expected = spec.expect.outcome, observation.outcome != expected {
            failures.append("outcome: expected \(expected), got \(observation.outcome ?? "none")")
        }
        if let probes = spec.expect.probes {
            for name in probes.keys.sorted() {
                guard let expected = probes[name] else { continue }
                let got = observation.frame?.probes[name]
                if got != expected {
                    failures.append("probe \(name): expected \(expected), got \(got ?? "none")")
                }
            }
        }
        if observation.actionsSent != observation.actionsHandled {
            failures.append("bypass: \(observation.actionsSent) actions sent, \(observation.actionsHandled) handled")
        }
        failures += observation.failures
        return failures
    }

    /// `accepted`, or `rejected <code>` for any other result code.
    private static func describe(_ result: String) -> String {
        result == "accepted" ? result : "rejected " + result
    }
}
#endif
