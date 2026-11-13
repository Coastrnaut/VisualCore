// EvidenceRecordObservation — feature 195 T-U09-014 (UA-F09; FR-U09-030, FR-U09-031; data-model section 4). The
// part of an evidence record the run itself can know, built from a scenario's observation. The host driver adds the
// environment, source and artifact fields it alone can know. Only in builds made for testing or for automation.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

extension EvidenceRecord {
    /// Whether this build was made with `VISUALCORE_AUTOMATION` (a plain debug build is not).
    public static var automationCompiled: Bool {
        #if VISUALCORE_AUTOMATION
        true
        #else
        false
        #endif
    }

    /// `simulator` in a simulator build, `device` otherwise.
    public static var environmentKind: String {
        #if targetEnvironment(simulator)
        "simulator"
        #else
        "device"
        #endif
    }

    /// The record of one run of `spec`, built from what the run observed and what the evaluator found.
    ///
    /// `failures` are the evaluator's failures; the result is `pass` when there are none, `fail` otherwise, or
    /// `error` when `error` names one (for example an unknown experience). Fields only the host can know are null.
    /// `renderer` is what the render host reported when the frame was read (feature 202); nil leaves it out.
    public static func observed(_ observation: ScenarioObservation, experience: ExperienceID, code: String,
                                run: String, build: String, process: String, qualityTier: Int?,
                                failures: [String], error: String? = nil,
                                probes: [(name: String, expected: String, observed: String)] = [],
                                thermalState: String, lowPower: Bool, renderer: RendererRecord? = nil) -> EvidenceRecord {
        let result: EvidenceResult = error != nil ? .error : (failures.isEmpty ? .pass : .fail)
        let steps = observation.steps.map { step in
            Step(control: step.control, values: step.values, result: step.result == "accepted" ? "accepted" : "rejected",
                 reason: step.result == "accepted" ? nil : step.result, digest: step.digest.flatMap(StateDigest.init(hex:)))
        }
        let digests = Digests(initial: observation.digests.initial.flatMap(StateDigest.init(hex:)),
                              final: observation.digests.final.flatMap(StateDigest.init(hex:)),
                              afterRestore: observation.digests.afterRestore.flatMap(StateDigest.init(hex:)),
                              afterReset: observation.digests.afterReset.flatMap(StateDigest.init(hex:)))
        let frames = observation.frame.map { frame in
            [Frame(nonBlank: frame.nonBlank,
                   probes: probes.map { ProbeResult(name: $0.name, expected: $0.expected, observed: $0.observed,
                                                    pass: $0.expected == $0.observed) },
                   path: nil, sha256: frame.sha256)]
        } ?? []
        let timing = Timing(launchMS: nil, preparationMS: observation.timing.preparation * 1_000,
                            shaderCompilationMS: observation.timing.setup * 1_000,
                            firstPresentMS: observation.timing.firstPresent * 1_000)
        let resources = Resources(footprintBytes: observation.resources.footprint,
                                  gpuBytes: observation.resources.gpuBytes, live: observation.resources.live,
                                  leaked: observation.resources.leaked)
        return EvidenceRecord(experience: experience.rawValue, code: code, scenario: observation.scenario,
                              seed: String(observation.seed), result: result, run: Run(id: run),
                              environment: Environment(kind: Self.environmentKind, renderer: renderer),
                              configuration: Configuration(build: build, automation: automationCompiled, qualityTier: qualityTier,
                                                           entitlement: "none", process: process),
                              steps: steps, digests: digests, frames: frames, timing: timing, pacing: nil,
                              resources: resources, thermalState: thermalState, lowPower: lowPower, battery: nil,
                              failures: error.map { [$0] + failures } ?? failures)
    }
}
#endif
