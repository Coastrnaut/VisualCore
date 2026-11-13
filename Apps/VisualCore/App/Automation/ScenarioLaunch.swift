// ScenarioLaunch — feature 195 T-U09-018 (UA-F09; FR-U09-011, FR-U09-013, FR-U09-015, FR-U09-034; research R4).
// The app's scenario run. When the launch environment asks for a scenario (`VISUALCORE_AUTORUN=scenario`), the
// app runs that one scenario of one experience through a real session, writes its evidence record into its own
// container and exits: 0 for a pass, 1 for a failure, 2 for an error. Nothing else can start a run: no URL, file
// or argument. The whole file exists only in builds made for testing or for automation.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// One experience a scenario run can open: how to build it and its manifest.
struct ScenarioTarget {
    /// The experience's id.
    let id: ExperienceID
    /// The code its records carry (`A01` …, or `debug`).
    let code: String
    /// Builds the experience for an open.
    let registration: ExperienceRegistration
    /// Its scenarios.
    let manifest: ScenarioManifest
}

/// The scenario run of the app.
enum ScenarioLaunch {
    /// The id the debug experience runs under in a scenario run; it is not a catalog id.
    static let debugID = ExperienceID(rawValue: "a98.debug-experience")

    /// Where the records go, below the app's Documents folder.
    static let evidenceFolder = "visualcore-evidence"

    /// The experiences a run can open: the real registry's experiences that carry a manifest and, in debug
    /// builds, the debug experience.
    static func targets() -> [ExperienceID: ScenarioTarget] {
        var found: [ExperienceID: ScenarioTarget] = [:]
        #if DEBUG
        if let debugID {
            found[debugID] = ScenarioTarget(id: debugID, code: "debug",
                                            registration: DebugExperience.registration(for: debugID),
                                            manifest: DebugExperience.manifest(for: debugID))
        }
        #endif
        return found
    }

    /// The outcome of a run: the exit code and where the record was written.
    struct Outcome: Equatable {
        /// 0 pass, 1 fail, 2 error.
        let exitCode: Int32
        /// The record file; nil when even an error record could not be written.
        let record: URL?
    }

    /// Runs the scenario `environment` asks for. Returns nil when the environment asks for none.
    ///
    /// `documents` is the folder the record goes below; `dataRoot` holds the saved states of save-restore;
    /// `defaults` gives the experience its storage values.
    @MainActor
    static func perform(environment: [String: String], documents: URL, dataRoot: URL, defaults: UserDefaults,
                        targets: [ExperienceID: ScenarioTarget] = targets()) async -> Outcome? {
        guard let parsed = ScenarioRequest.parse(environment) else { return nil }
        let request: ScenarioRequest
        switch parsed {
        case .success(let value):
            request = value
        case .failure(let error):
            return write(errorRecord(experience: nil, scenario: environment[ScenarioRequest.scenarioKey],
                                     run: "invalid-request", message: error.code),
                         run: "invalid-request", name: "request-error", documents: documents, code: 2)
        }
        let name = "\(request.experience.rawValue).\(request.scenario)"
        guard let target = targets[request.experience] else {
            return write(errorRecord(experience: request.experience, scenario: request.scenario, run: request.run,
                                     message: "request.unknown-experience"),
                         run: request.run, name: name, documents: documents, code: 2)
        }
        guard var spec = target.manifest.scenarios.first(where: { $0.name == request.scenario }) else {
            return write(errorRecord(experience: request.experience, scenario: request.scenario, run: request.run,
                                     message: "request.unknown-scenario"),
                         run: request.run, name: name, documents: documents, code: 2)
        }
        if request.phase == .restore {
            // The second launch restores and compares; the actions were played by the first launch.
            spec = ScenarioSpec(name: spec.name, seed: spec.seed, entries: [], expect: ScenarioExpectations())
        }
        if let seed = request.seed, seed != spec.seed {
            spec = ScenarioSpec(name: spec.name, seed: seed, entries: spec.entries, expect: spec.expect,
                                cycles: spec.cycles, seconds: spec.seconds)
        }

        let store = SavedStateStore(root: dataRoot)
        let launch = ExperienceLaunch(storage: ExperienceStorage(id: target.id, root: dataRoot, defaults: defaults))
        let registration = target.registration
        let make: ScenarioRunner.RequestMaker = { seed, snapshot in
            ExperienceOpenRequest(id: target.id, seed: seed, snapshot: snapshot) { registration.make(launch) }
        }
        var saved: ExperienceSnapshot?
        if request.phase == .restore, case .state(let snapshot) = store.load(target.id) { saved = snapshot }
        let runner = ScenarioRunner(session: ExperienceSession())
        let phase: ScenarioPhase = switch request.phase {
        case .single: .single
        case .save: .save
        case .restore: .restore
        }
        let result = await runner.run(spec, request: make, phase: phase, savedSnapshot: saved,
                                      expectedDigest: request.expectedDigest?.hex)
        var failures = ScenarioEvaluator.failures(spec, result.observation)
        if phase == .save, let snapshot = result.snapshot {
            do {
                try store.save(snapshot)
            } catch {
                failures.append("save phase: the snapshot could not be stored (\(error.code))")
            }
        }
        let record = EvidenceRecord.observed(result.observation, experience: target.id, code: target.code,
                                             run: request.run, build: buildConfiguration, process: result.process,
                                             qualityTier: nil, failures: failures, probes: result.probes,
                                             thermalState: thermalState, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        return write(record, run: request.run, name: name, documents: documents, code: failures.isEmpty ? 0 : 1)
    }

    // MARK: Records

    /// `Debug` or `Release`.
    static var buildConfiguration: String {
        #if DEBUG
        "Debug"
        #else
        "Release"
        #endif
    }

    /// The thermal state as the system reports it.
    static var thermalState: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    /// The id an error record carries when the request named no valid experience.
    static let unknownID = ExperienceID(rawValue: "a96.unknown-experience")

    /// A record of a run that could not start; nil only if no id at all is available.
    static func errorRecord(experience: ExperienceID?, scenario: String?, run: String, message: String) -> EvidenceRecord? {
        guard let id = experience ?? unknownID else { return nil }
        let name = scenario.flatMap { ScenarioManifestValidator.isValidName($0) ? $0 : nil } ?? "unknown"
        let observation = ScenarioObservation(scenario: name, seed: 0)
        return EvidenceRecord.observed(observation, experience: id,
                                       code: "unknown", run: run, build: buildConfiguration, process: "single",
                                       qualityTier: nil, failures: [], error: message, thermalState: thermalState,
                                       lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    /// Writes `record` atomically to `Documents/visualcore-evidence/<run>/<name>.json`.
    static func write(_ record: EvidenceRecord?, run: String, name: String, documents: URL, code: Int32) -> Outcome {
        guard let record else { return Outcome(exitCode: 2, record: nil) }
        let folder = documents.appendingPathComponent(evidenceFolder, isDirectory: true)
            .appendingPathComponent(run, isDirectory: true)
        let file = folder.appendingPathComponent(name + ".json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try record.encoded().write(to: file, options: .atomic)
            return Outcome(exitCode: code, record: file)
        } catch {
            return Outcome(exitCode: 2, record: nil)
        }
    }
}

/// What a scenario run shows: a plain line. The session's host view is not put in the window, so that no display
/// link draws frames on its own; the runner draws every frame itself.
struct ScenarioHostView: View {
    let environment: [String: String]
    /// Ends the process with the run's exit code (injected in tests).
    let exit: @MainActor (Int32) -> Void

    var body: some View {
        Text(verbatim: "Running scenario")
            .font(.body)
            .task {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let outcome = await ScenarioLaunch.perform(environment: environment, documents: documents,
                                                           dataRoot: ExperienceDataStore.defaultRoot(),
                                                           defaults: .standard)
                exit(outcome?.exitCode ?? 2)
            }
    }
}
#endif
