// ScenarioRunner — feature 195 T-U09-014 (UA-F09; FR-U09-010, FR-U09-013, FR-U09-014, FR-U09-040, FR-U09-060;
// research R3). Plays one scenario of an experience's manifest through a real `ExperienceSession`: the session opens
// the experience, the actions reach the experience's own reducer, and the runner reads what a person's device would
// show and keep: digests, the outcome, the rendered frame with its probes, stage timings and resources. Only in builds
// made for testing or for automation.
#if DEBUG || VISUALCORE_AUTOMATION
import CryptoKit
import Foundation
import UIKit
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreRendering

/// Which part of a save-restore scenario a run is: the whole of it in one process, the first launch that saves, or
/// the second launch that restores.
public enum ScenarioPhase: String, Sendable, CaseIterable {
    /// Every step in this process (the package-test path; the record says `single`).
    case single
    /// The first launch: actions, then the snapshot is handed back to the caller to store.
    case save
    /// The second launch: the stored snapshot is restored and its digest compared.
    case restore
}

/// What one run produced: the observation, the snapshot a save phase took, and the frame it read.
public struct ScenarioRunResult: Sendable {
    /// What the run observed, with the failures the runner found itself.
    public let observation: ScenarioObservation
    /// The snapshot the save phase took; nil in other phases.
    public let snapshot: ExperienceSnapshot?
    /// The RGBA bytes of the frame read (rows bottom-up), with its size; nil when no frame was read.
    public let frame: (pixels: [UInt8], width: Int, height: Int)?
    /// The probes as checked: name, expected class, observed class.
    public let probes: [(name: String, expected: String, observed: String)]
    /// `single` when every part ran in this process, `two-launch` for a save or restore phase.
    public let process: String
}

/// Runs scenarios of a manifest through one `ExperienceSession` on the main actor.
///
/// Every action of a scenario goes through the experience's scripted run (`Experience.runScenario`), which hands
/// each action to the engine's reducer exactly as `handle(control:values:)` does. The runner never sets state,
/// digest or outcome. Every wait has a limit.
@MainActor
public final class ScenarioRunner {
    /// Builds the open request for a seed and an optional snapshot to restore.
    public typealias RequestMaker = @MainActor (_ seed: UInt64, _ snapshot: ExperienceSnapshot?) -> ExperienceOpenRequest

    /// The session the scenarios run in.
    public let session: ExperienceSession
    /// The size the render host's view gets when it has none yet (points).
    public var surfaceSize = CGSize(width: 96, height: 96)
    /// Cycles of teardown-reentry when the scenario names none.
    public static let defaultCycles = 5
    /// Frames drawn per teardown-reentry cycle, so that the growth rule gets its samples.
    public static let framesPerCycle = 12
    /// Frames drawn before endurance samples begin, so that first-use allocations are not counted as growth.
    public static let warmUpFrames = 120
    /// The most frames the runner draws while it waits for something to be drawn.
    public static let maxFrameAttempts = 120

    /// Creates a runner on `session`. The session's snapshot sink, if any, sees the closes of the run.
    public init(session: ExperienceSession) {
        self.session = session
    }

    // MARK: Run

    /// Runs `spec` with the experience `request` builds. `savedSnapshot` is the snapshot a restore phase restores;
    /// `expectedDigest` is the digest it must give.
    public func run(_ spec: ScenarioSpec, request: RequestMaker, phase: ScenarioPhase = .single,
                    savedSnapshot: ExperienceSnapshot? = nil, expectedDigest: String? = nil) async -> ScenarioRunResult {
        var record = Record(spec: spec)
        switch spec.name {
        case "cancel-prepare":
            await cancelPrepare(spec, request: request, into: &record)
        case "teardown-reentry":
            await teardownReentry(spec, request: request, into: &record)
        case "endurance":
            await endurance(spec, request: request, into: &record)
        default:
            await playthrough(spec, request: request, phase: phase, savedSnapshot: savedSnapshot,
                              expectedDigest: expectedDigest, into: &record)
        }
        if session.state != .idle { session.close() }
        return record.result()
    }

    // MARK: Scenarios

    /// Every scenario that opens once and plays actions: launch-first-frame, input-response, completion, rejection,
    /// save-restore, reset, suspend-resume and the extra scenarios (fixtures, acceptance, hero, full-playthrough).
    private func playthrough(_ spec: ScenarioSpec, request: RequestMaker, phase: ScenarioPhase,
                             savedSnapshot: ExperienceSnapshot?, expectedDigest: String?,
                             into record: inout Record) async {
        if phase == .restore {
            await restorePhase(spec, request: request, snapshot: savedSnapshot, expectedDigest: expectedDigest,
                               into: &record)
            return
        }
        guard let experience = await open(request(spec.seed, nil), into: &record) else { return }
        record.initial = digest(of: experience)
        if spec.name == "suspend-resume" {
            suspendResume(experience, into: &record)
        }
        play(spec, on: experience, into: &record)
        record.final = digest(of: experience)
        record.outcome = experience.diagnostics.outcome?.code
        if drawsFrame(spec) { readFrame(of: experience, into: &record) }
        if spec.name == "rejection", !record.steps.isEmpty, record.steps.allSatisfy({ $0.result != "accepted" }),
           record.final != record.initial {
            record.failures.append("rejection: the digest changed although every action was rejected")
        }
        switch spec.name {
        case "save-restore":
            await saveRestore(experience, spec: spec, request: request, phase: phase, into: &record)
            if phase == .single, let restored = record.afterRestore, restored != record.final {
                record.failures.append("after-restore digest: expected \(record.final ?? "none"), got \(restored)")
            }
        case "reset":
            do {
                try experience.reset()
                record.afterReset = digest(of: experience)
            } catch {
                record.failures.append("reset refused: \(error.failure.code)")
            }
        default:
            break
        }
        record.capture(session)
    }

    /// Plays the entries one by one, reading the result and the digest after each action.
    private func play(_ spec: ScenarioSpec, on experience: any Experience, into record: inout Record) {
        for entry in spec.entries {
            let before = experience.diagnostics
            let run = ExperienceScenario(seed: spec.seed, entries: [.init(steps: entry.steps, action: entry.action)])
            let result = experience.runScenario(run)
            if let error = result.error {
                record.failures.append("entry stopped: \(error.code)")
                return
            }
            guard let action = entry.action else { continue }
            record.sent += 1
            let after = experience.diagnostics
            let handled = (after.acceptedActions + after.rejectedActions) - (before.acceptedActions + before.rejectedActions)
            record.handled += max(0, handled)
            record.steps.append(StepObservation(control: action.control, values: action.values,
                                                result: result.results.last ?? "none", digest: result.digest?.hex))
        }
    }

    /// Takes the snapshot, then restores it in a new open (single) or hands it back (save).
    private func saveRestore(_ experience: any Experience, spec: ScenarioSpec, request: RequestMaker,
                             phase: ScenarioPhase, into record: inout Record) async {
        let snapshot: ExperienceSnapshot
        do {
            snapshot = try experience.snapshot()
        } catch {
            record.failures.append("snapshot refused: \(error.failure.code)")
            return
        }
        if phase == .save {
            record.snapshot = snapshot
            record.process = "two-launch"
            return
        }
        record.process = "single"
        record.capture(session)
        session.close()
        var restored = request(spec.seed, snapshot)
        restored.refusedSnapshotFails = true
        guard let again = await openRestored(restored, into: &record) else { return }
        record.afterRestore = digest(of: again)
    }

    /// The second launch of save-restore: open with the stored snapshot and compare the digest.
    private func restorePhase(_ spec: ScenarioSpec, request: RequestMaker, snapshot: ExperienceSnapshot?,
                              expectedDigest: String?, into record: inout Record) async {
        record.process = "two-launch"
        guard let snapshot else {
            record.failures.append("restore phase without a stored snapshot")
            return
        }
        var restored = request(spec.seed, snapshot)
        restored.refusedSnapshotFails = true
        guard let experience = await openRestored(restored, into: &record) else { return }
        record.afterRestore = digest(of: experience)
        record.final = record.afterRestore
        if let expectedDigest, record.afterRestore != expectedDigest {
            record.failures.append("after-restore digest: expected \(expectedDigest), got \(record.afterRestore ?? "none")")
        }
        record.capture(session)
    }

    /// Background then foreground: the digest does not change while away, and the first frame after the return
    /// runs at most the steps of one frame.
    private func suspendResume(_ experience: any Experience, into record: inout Record) {
        guard let host = session.renderHost else { return }
        drawFrames(host, count: 3)
        let before = experience.diagnostics
        session.setScenePhase(.background)
        drawFrames(host, count: 3)
        let away = experience.diagnostics
        if away.digest != before.digest { record.failures.append("suspend-resume: the digest changed while suspended") }
        if away.stepIndex != before.stepIndex { record.failures.append("suspend-resume: steps ran while suspended") }
        session.setScenePhase(.active)
        drawFrames(host, count: 1)
        let back = experience.diagnostics
        let ran = back.stepIndex - away.stepIndex
        if ran > ExperienceEngineLimits.maxStepsPerFrame {
            record.failures.append("suspend-resume: \(ran) steps after the return (catch-up)")
        }
    }

    /// Opens and closes the experience several times: no live or leaked GPU object after each close, and no growth
    /// of memory or GPU bytes by the resource growth rule.
    private func teardownReentry(_ spec: ScenarioSpec, request: RequestMaker, into record: inout Record) async {
        let cycles = spec.cycles ?? Self.defaultCycles
        var samples: [ResourceSample] = []
        for cycle in 1...max(1, cycles) {
            guard let experience = await open(request(spec.seed, nil), into: &record) else { return }
            if cycle == 1 { record.initial = digest(of: experience) }
            if let host = session.renderHost {
                for _ in 0..<Self.framesPerCycle {
                    autoreleasepool { _ = host.renderOneFrame(present: false) }
                    samples.append(ResourceSample(footprintBytes: ProcessMemory.footprint(),
                                                  gpuBytes: host.resources.stats.totalBytes))
                }
            }
            record.capture(session)
            session.close()
            let counts = session.diagnostics.lastCloseCounts
            if let counts, counts.objects != 0 || counts.leaked != 0 {
                record.failures.append("teardown-reentry: cycle \(cycle) left \(counts.objects) live and "
                                       + "\(counts.leaked) leaked GPU objects")
            }
            if session.hostsAlive != 0 {
                record.failures.append("teardown-reentry: cycle \(cycle) left a render host alive")
            }
            record.live = counts?.objects ?? 0
            record.leaked = counts?.leaked ?? 0
        }
        judge(samples, name: "teardown-reentry", into: &record)
    }

    /// Opens and leaves at once, while the experience prepares: the open ends cancelled and nothing arrives.
    private func cancelPrepare(_ spec: ScenarioSpec, request: RequestMaker, into record: inout Record) async {
        let cancelledBefore = session.diagnostics.cancelledPreparations
        let openRequest = request(spec.seed, nil)
        let opening = Task { @MainActor in await self.session.open(openRequest) }
        for _ in 0..<Self.maxFrameAttempts where session.state != .preparing { await Task.yield() }
        let caught = session.state == .preparing
        session.close()
        let result = await opening.value
        if !caught || result != .cancelled {
            record.failures.append("cancel-prepare: the preparation was not cancelled (result \(result))")
        }
        if session.diagnostics.cancelledPreparations != cancelledBefore + 1 {
            record.failures.append("cancel-prepare: no cancelled preparation was counted")
        }
        if session.experience != nil || session.renderHost != nil {
            record.failures.append("cancel-prepare: something remained after the leave")
        }
    }

    /// Draws frames for the scenario's seconds and judges memory and GPU bytes by the growth rule.
    private func endurance(_ spec: ScenarioSpec, request: RequestMaker, into record: inout Record) async {
        guard let experience = await open(request(spec.seed, nil), into: &record),
              let host = session.renderHost else { return }
        record.initial = digest(of: experience)
        autoreleasepool { for _ in 0..<Self.warmUpFrames { _ = host.renderOneFrame(present: false) } }
        // The scenario's seconds are simulated time: 60 frames of 1/60 s each per second, drawn in
        // `GrowthRule.minimumSamples` blocks with one sample after each (the endurance pattern of UA-F06), so the
        // run does not depend on how fast the machine draws.
        let totalFrames = max(GrowthRule.minimumSamples, (spec.seconds ?? 60) * 60)
        let blocks = GrowthRule.minimumSamples
        let framesPerBlock = max(1, totalFrames / blocks)
        var samples: [ResourceSample] = []
        samples.reserveCapacity(blocks)
        var drawn = 0
        for _ in 0..<blocks {
            autoreleasepool {
                for _ in 0..<framesPerBlock where host.renderOneFrame(present: false) { drawn += 1 }
            }
            samples.append(ResourceSample(footprintBytes: ProcessMemory.footprint(),
                                          gpuBytes: host.resources.stats.totalBytes))
        }
        if drawn != blocks * framesPerBlock {
            record.failures.append("endurance: \(drawn) of \(blocks * framesPerBlock) frames were drawn")
        }
        let steps = experience.diagnostics.stepIndex
        record.final = digest(of: experience)
        record.capture(session)
        judge(samples, name: "endurance", into: &record)
        print("ENDURANCE \(drawn) frames, \(steps) steps, samples \(samples.first.map { "\($0)" } ?? "-") … "
              + "\(samples.last.map { "\($0)" } ?? "-")")
    }

    // MARK: Helpers

    /// Opens `request` while the scene is in the background, so that the restored state is read before any frame
    /// advances it (the open ends suspended, the experience ready); nil with a failure when the open did not end
    /// suspended. The scene phase is active again afterwards.
    private func openRestored(_ request: ExperienceOpenRequest, into record: inout Record) async -> (any Experience)? {
        session.setScenePhase(.background)
        defer { if session.state != .suspended { session.setScenePhase(.active) } }
        let result = await session.open(request)
        guard result == .suspended, let experience = session.experience else {
            let code = session.failure.map { "\($0.failure.code) at \($0.stage.rawValue)" } ?? "\(result)"
            record.failures.append("open failed: \(code)")
            session.setScenePhase(.active)
            return nil
        }
        record.timing(from: session)
        return experience
    }

    /// Opens `request`, gives the host a surface, draws the first frame and resets the experience to the state of
    /// a fresh preparation, so that a scenario's digests do not depend on how many frames the open drew; nil (with
    /// a failure) when the open did not end running.
    private func open(_ request: ExperienceOpenRequest, into record: inout Record) async -> (any Experience)? {
        let result = await session.open(request)
        guard result == .running, let experience = session.experience else {
            let code = session.failure.map { "\($0.failure.code) at \($0.stage.rawValue)" } ?? "\(result)"
            record.failures.append("open failed: \(code)")
            return nil
        }
        if let host = session.renderHost {
            if host.view.bounds.isEmpty {
                host.view.frame = CGRect(origin: .zero, size: surfaceSize)
            }
            host.view.layoutIfNeeded()
            _ = host.renderOneFrame(present: false)
        }
        record.timing(from: session)
        do {
            try experience.reset()
        } catch {
            record.failures.append("reset after the open refused: \(error.failure.code)")
            return nil
        }
        return experience
    }

    private func digest(of experience: any Experience) -> String? {
        experience.diagnostics.digest?.hex
    }

    private func drawsFrame(_ spec: ScenarioSpec) -> Bool {
        spec.name == "launch-first-frame" || spec.name == "hero" || spec.expect.probes?.isEmpty == false
    }

    private func drawFrames(_ host: RenderHost, count: Int) {
        for _ in 0..<count { _ = host.renderOneFrame(present: false) }
    }

    /// Draws one frame, reads it, checks that it is not blank and checks every probe the experience declares.
    private func readFrame(of experience: any Experience, into record: inout Record) {
        guard let host = session.renderHost else {
            record.failures.append("frame: no render host")
            return
        }
        var drawn = false
        for _ in 0..<Self.maxFrameAttempts where !drawn { drawn = host.renderOneFrame(present: false) }
        let pixels = host.readPixels()
        let size = host.pixelSize
        let nonBlank = FrameChecks.isNonBlank(pixels, width: size.width, height: size.height)
        if !drawn || pixels.isEmpty { record.failures.append("frame: nothing was drawn") }
        if !nonBlank { record.failures.append("frame: blank") }
        let probes = experience.frameProbes
        if probes.isEmpty { record.failures.append("frame: no probe declared") }
        var observed: [String: String] = [:]
        for probe in probes {
            let found = FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue ?? "none"
            observed[probe.name] = found
            record.probes.append((probe.name, probe.expected, found))
            if found != probe.expected {
                record.failures.append("probe \(probe.name): declared \(probe.expected), drawn \(found)")
            }
        }
        let hash = SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
        record.frame = FrameObservation(width: size.width, height: size.height, sha256: hash, nonBlank: nonBlank,
                                        probes: observed)
        record.pixels = (pixels, size.width, size.height)
    }

    private func judge(_ samples: [ResourceSample], name: String, into record: inout Record) {
        let verdict = GrowthRule.judge(samples)
        if !verdict.passes { record.failures.append("\(name): \(verdict)") }
    }

    // MARK: Record

    /// What a run collects while it goes.
    private struct Record {
        let spec: ScenarioSpec
        var steps: [StepObservation] = []
        var initial: String?
        var final: String?
        var afterRestore: String?
        var afterReset: String?
        var outcome: String?
        var frame: FrameObservation?
        var pixels: (pixels: [UInt8], width: Int, height: Int)?
        var probes: [(name: String, expected: String, observed: String)] = []
        var timingValue = ScenarioTiming()
        var footprint = 0
        var gpuBytes = 0
        var live = 0
        var leaked = 0
        var sent = 0
        var handled = 0
        var failures: [String] = []
        var snapshot: ExperienceSnapshot?
        var process = "single"

        init(spec: ScenarioSpec) {
            self.spec = spec
        }

        @MainActor
        mutating func timing(from session: ExperienceSession) {
            let t = session.diagnostics.timings
            timingValue = ScenarioTiming(preparation: t.prepare ?? 0, setup: t.setup ?? 0,
                                         firstPresent: t.firstPresent ?? t.firstFrame ?? 0,
                                         programsCompiled: t.programsCompiled ?? 0)
        }

        @MainActor
        mutating func capture(_ session: ExperienceSession) {
            footprint = ProcessMemory.footprint() ?? footprint
            if let host = session.renderHost { gpuBytes = host.resources.stats.totalBytes }
        }

        func result() -> ScenarioRunResult {
            let observation = ScenarioObservation(
                scenario: spec.name, seed: spec.seed, steps: steps,
                digests: ObservedDigests(initial: initial, final: final, afterRestore: afterRestore,
                                         afterReset: afterReset),
                outcome: outcome, frame: frame, timing: timingValue,
                resources: ScenarioResources(footprint: footprint, gpuBytes: gpuBytes, live: live, leaked: leaked),
                actionsSent: sent, actionsHandled: handled, failures: failures)
            return ScenarioRunResult(observation: observation, snapshot: snapshot, frame: pixels, probes: probes,
                                     process: process)
        }
    }
}

/// The engine's frame limit the runner checks catch-up against.
enum ExperienceEngineLimits {
    /// The most fixed steps one frame runs (the engine's fixed-step runner).
    static let maxStepsPerFrame = 8
}
#endif
