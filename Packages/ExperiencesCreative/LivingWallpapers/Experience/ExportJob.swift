// ExportJob — feature 141 (A19-P04) T-A19-405 (FR-A19-403; clarification Q2; data-model.md "ExportJob";
// contracts/save.md "Job"). The one shipping export path: the controls start, cancel and retry this job, which runs
// the step code of `StillExport` one step at a time:
//
//   1. plan, on the main actor: the A19-P01 planner, then the format check (a refusal keeps `lastRefusal`);
//   2. render, on the main actor, because the host requires it (the host releases its render target on every path);
//   3. encode, in a detached task (`StillExport.encodeStep`, CPU work on a `Sendable` `StillImage`);
//   4. verify, in a detached task (`StillExport.verifyStep`, CPU work on `Data`);
//   5. write, on the main actor: "<Scene> <Device> <W>x<H>.<ext>" in the exporter's folder.
//
// The progress published for the controls is 0.2 after plan, 0.4 after render, 0.7 after encode, 0.85 after verify
// and 1.0 after write. `cancel()` sets a flag that is checked at each step boundary; a cancelled or failed job
// removes its file, and a new job first removes the file of the previous one, so the folder holds at most one file
// of this job. `retry()` replays the last request, with the refusal's offered plan after a `does-not-fit`. Each
// outcome is announced once through `EditorModel.record` (done, failed, cancelled or the notice), and each written
// export is recorded in the `HistoryStore` when one is given.
import Foundation
import LivingWallpapersCore
import Observation
import VisualCoreExperienceHost
import VisualCoreRendering

/// The export job of the controls: plan, render, encode, verify, write, with progress, cancel and retry.
@MainActor
@Observable
final class ExportJob {
    /// A step of the job, in order.
    enum Step: String, CaseIterable, Sendable {
        /// Planning the size and checking the format.
        case plan
        /// Rendering the still on the main actor.
        case render
        /// Encoding the still off the main actor.
        case encode
        /// Reading the encoded data back off the main actor.
        case verify
        /// Writing the file.
        case write

        /// The progress published once this step is done: 0.2, 0.4, 0.7, 0.85 or 1.0.
        var progressAfter: Double {
            switch self {
            case .plan: return 0.2
            case .render: return 0.4
            case .encode: return 0.7
            case .verify: return 0.85
            case .write: return 1.0
            }
        }
    }

    /// Where the job is.
    enum State: Equatable, Sendable {
        /// No job yet.
        case idle
        /// The job runs `step`, with `progress` done so far (0 … 1).
        case running(step: Step, progress: Double)
        /// The file was written.
        case done(StillExport.Output)
        /// The job was cancelled; its file, if any, was removed.
        case cancelled
        /// The job failed for `reason`; its file, if any, was removed.
        case failed(StillExport.FailureReason)
    }

    /// What a job was asked to export, kept for `retry()`.
    enum Request: Equatable, Sendable {
        /// The project, planned at `maxEdge`.
        case project(WallpaperProject, maxEdge: Int)
        /// An existing plan (an offered size) of the project, at the project's animation time.
        case plan(ExportPlan, project: WallpaperProject, maxEdge: Int)

        /// The project of the request.
        var project: WallpaperProject {
            switch self {
            case .project(let project, _), .plan(_, let project, _): return project
            }
        }

        /// The edge limit of the request.
        var maxEdge: Int {
            switch self {
            case .project(_, let maxEdge), .plan(_, _, let maxEdge): return maxEdge
            }
        }
    }

    /// The exporter whose step code and folder the job uses.
    let export: StillExport
    /// The editor whose announcement path reports each outcome.
    let editor: EditorModel
    /// The history each written export is recorded in; nil records nothing.
    let history: HistoryStore?
    /// Where the job is.
    private(set) var state: State = .idle
    /// The planner's refusal of the last job (its `offeredPlan(format:)` is what `retry()` uses); nil otherwise.
    private(set) var lastRefusal: ExportRefusal?
    /// The render error of the last job; nil otherwise.
    @ObservationIgnored private(set) var lastRenderError: OffscreenRenderError?
    /// The progress values published by the last job, in order (0.2, 0.4, 0.7, 0.85, 1.0 on success).
    @ObservationIgnored private(set) var progressLog: [Double] = []
    /// The steps the last job completed, in order.
    @ObservationIgnored private(set) var completedSteps: [Step] = []
    /// The number of outcomes the job announced (one per finished job).
    @ObservationIgnored private(set) var announcedOutcomes = 0
    /// The last request; nil before the first.
    @ObservationIgnored private(set) var lastRequest: Request?
    /// The renderer of the last request.
    @ObservationIgnored private var lastRender: StillExport.Render?
    /// The port of the last request's announcement.
    @ObservationIgnored private var lastPort: ExperienceActionPort?
    /// The output of the last written job (removed when the next job starts).
    @ObservationIgnored private var written: StillExport.Output?
    /// Whether a cancel was asked for during the running job.
    @ObservationIgnored private var cancelRequested = false

    /// A job over `export`'s step code and folder, announcing through `editor` and recording in `history`.
    init(export: StillExport, editor: EditorModel, history: HistoryStore? = nil) {
        self.export = export
        self.editor = editor
        self.history = history
    }

    // MARK: Reading

    /// Whether the job is running.
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// The progress of the running job (0 … 1); 1 when done, 0 otherwise.
    var progress: Double {
        switch state {
        case .running(_, let progress): return progress
        case .done: return 1
        default: return 0
        }
    }

    /// The written output while the job is done; nil otherwise.
    var output: StillExport.Output? {
        if case .done(let output) = state { return output }
        return nil
    }

    /// The share item of the written file, only while that file exists.
    var shareItem: WallpaperExportFile? { WallpaperExportFile.item(for: output) }

    /// Whether `retry()` can replay a request: the last job failed or was cancelled.
    var canRetry: Bool {
        guard lastRequest != nil, lastRender != nil else { return false }
        switch state {
        case .failed, .cancelled: return true
        default: return false
        }
    }

    // MARK: Running

    /// Exports `project` planned at `maxEdge` with `render`, announcing the outcome once (through `port` when
    /// given). `cancelAfter` (a test seam) asks for a cancel once that step is done. Does nothing while running.
    func start(project: WallpaperProject, maxEdge: Int, render: @escaping StillExport.Render,
               port: ExperienceActionPort? = nil, cancelAfter: Step? = nil) async {
        await run(.project(project, maxEdge: maxEdge), render: render, port: port, cancelAfter: cancelAfter)
    }

    /// Exports the existing `plan` (an offered size) of `project` at its animation time with `render`; `maxEdge` is
    /// the limit the offer was made at. Does nothing while running.
    func start(plan: ExportPlan, project: WallpaperProject, maxEdge: Int, render: @escaping StillExport.Render,
               port: ExperienceActionPort? = nil, cancelAfter: Step? = nil) async {
        await run(.plan(plan, project: project, maxEdge: maxEdge), render: render, port: port,
                  cancelAfter: cancelAfter)
    }

    /// Replays the last request with its renderer; after a `does-not-fit` it exports the refusal's offered plan in
    /// the project's format instead. `cancelAfter` is the test seam of `start`. Does nothing without a request or
    /// while running.
    func retry(cancelAfter: Step? = nil) async {
        guard let request = lastRequest, let render = lastRender else { return }
        var next = request
        if case .failed(.doesNotFit) = state, let refusal = lastRefusal,
           let offered = refusal.offeredPlan(format: request.project.format) {
            next = .plan(offered, project: request.project, maxEdge: request.maxEdge)
        }
        await run(next, render: render, port: lastPort, cancelAfter: cancelAfter)
    }

    /// Asks the running job to stop at its next step boundary.
    func cancel() {
        guard isRunning else { return }
        cancelRequested = true
    }

    /// Removes the written file (once it was handed on) and returns the job to idle; returns whether a file was
    /// removed.
    @discardableResult
    func discard() -> Bool {
        let removed = removeWritten()
        if case .done = state { state = .idle }
        return removed
    }

    // MARK: Steps

    /// Runs `request` step by step (see the file header).
    private func run(_ request: Request, render: @escaping StillExport.Render, port: ExperienceActionPort?,
                     cancelAfter: Step?) async {
        guard !isRunning else { return }
        removeWritten()
        lastRequest = request
        lastRender = render
        lastPort = port
        lastRefusal = nil
        lastRenderError = nil
        progressLog = []
        completedSteps = []
        cancelRequested = false
        state = .running(step: .plan, progress: 0)

        // 1. Plan (main actor).
        let project = request.project
        let plan: ExportPlan
        switch request {
        case .plan(let offered, _, _):
            plan = offered
        case .project(_, let maxEdge):
            switch ExportPlanner.plan(project: project, maxEdge: maxEdge) {
            case .success(let planned):
                plan = planned
            case .failure(let refusal):
                lastRefusal = refusal
                return finish(failure: StillExport.reason(of: refusal), file: nil)
            }
        }
        if let refused = StillExport.formatStep(plan) { return finish(failure: refused, file: nil) }
        if stop(after: .plan, cancelAfter, file: nil) { return }

        // 2. Render (main actor; the host asserts it).
        let image: StillImage
        do {
            image = try render(plan.width, plan.height, project.animationTime)
        } catch {
            lastRenderError = error
            return finish(failure: .render, file: nil)
        }
        if stop(after: .render, cancelAfter, file: nil) { return }

        // 3. Encode (detached; `image` and `plan` are Sendable values).
        let encoded = await Task.detached(priority: .userInitiated) {
            StillExport.encodeStep(image, plan: plan)
        }.value
        guard let data = encoded else { return finish(failure: .encoding, file: nil) }
        if stop(after: .encode, cancelAfter, file: nil) { return }

        // 4. Verify (detached; `data` and `plan` are Sendable values).
        let verified = await Task.detached(priority: .userInitiated) {
            StillExport.verifyStep(data, plan: plan)
        }.value
        guard let result = verified else { return finish(failure: .verification, file: nil) }
        if stop(after: .verify, cancelAfter, file: nil) { return }

        // 5. Write (main actor).
        let name = WallpaperExportFile.fileName(project: project, plan: plan)
        guard let url = export.writeStep(data, plan: plan, name: name) else {
            return finish(failure: .encoding, file: nil)
        }
        if stop(after: .write, cancelAfter, file: url) { return }

        let output = StillExport.Output(url: url, result: result, plan: plan)
        written = output
        state = .done(output)
        history?.record(plan: plan, project: project)
        announce()
    }

    /// Records `step` as done and publishes its progress; when a cancel was asked for (or `cancelAfter` is `step`)
    /// removes `file`, ends the job `cancelled`, announces it and returns true.
    private func stop(after step: Step, _ cancelAfter: Step?, file: URL?) -> Bool {
        completedSteps.append(step)
        progressLog.append(step.progressAfter)
        if cancelAfter == step { cancelRequested = true }
        guard cancelRequested else {
            let next = Step.allCases.firstIndex(of: step).map { $0 + 1 } ?? Step.allCases.count
            let shown = next < Step.allCases.count ? Step.allCases[next] : step
            state = .running(step: shown, progress: step.progressAfter)
            return false
        }
        export.remove(file)
        state = .cancelled
        announce()
        return true
    }

    /// Removes `file`, ends the job `failed(reason)` and announces it.
    private func finish(failure reason: StillExport.FailureReason, file: URL?) {
        export.remove(file)
        state = .failed(reason)
        announce()
    }

    /// Announces the outcome of the finished job once through the editor.
    private func announce() {
        guard let request = lastRequest,
              let outcome = EditorModel.outcome(of: state, refusal: lastRefusal, limit: request.maxEdge,
                                                orientation: request.project.orientation) else { return }
        announcedOutcomes += 1
        editor.record(outcome, port: lastPort)
    }

    /// Removes the previous job's written file; returns whether a file was removed.
    @discardableResult
    private func removeWritten() -> Bool {
        guard let previous = written else { return false }
        written = nil
        let existed = FileManager.default.fileExists(atPath: previous.url.path)
        export.remove(previous.url)
        return existed
    }
}
