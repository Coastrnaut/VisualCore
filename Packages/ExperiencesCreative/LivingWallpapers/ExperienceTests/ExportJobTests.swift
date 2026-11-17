// ExportJobTests — feature 141 (A19-P04) T-A19-406 (FR-A19-403; SC-A19-402; clarification Q2; contracts/save.md
// "Job"). The export job on the real host inside the one app's session on the simulator, opened as StillExportTests
// opens it, short runs only (the iPhone SE template, 750 × 1334; no sleep, no wall-clock assertion), each job over its
// own temporary folder (emptied first and removed at the end):
//   - on success the progress is 0.2, 0.4, 0.7, 0.85 and 1.0, the file is written under its documented name, and
//     the state is done;
//   - for a cancel after each step (plan, render, encode, verify, write) the folder holds 0 files, the host's live
//     GPU count is unchanged, and the live picture still renders;
//   - a failure names its reason (`does-not-fit` at an edge limit of 512, `render` with no experience open), and
//     `retry` succeeds with the offered plan;
//   - each outcome (done, cancelled, failed, the notice) is announced exactly once, through a fresh recording sink
//     per outcome (the route holds a second announcement at the same instant, so one sink per outcome).
// This job is the one shipping path; StillExportTests keeps covering `StillExport.run`, the synchronous composition
// of the same step code.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreUI

@MainActor
@Suite(.serialized) struct ExportJobTests {
    /// The index of the iPhone SE (3rd generation) template, 750 × 1334.
    static let smallTemplate = 4

    /// The session's timed still as a job renderer.
    private func renderer(_ session: ExperienceSession) -> StillExport.Render {
        { (width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height, time: time)
        }
    }

    /// Opens the experience on the iPhone SE template and returns the session, the project and the host's limit.
    private func openSmall(_ session: ExperienceSession, job: ExportJob) async throws -> (WallpaperProject, Int) {
        let shell = try await WallpaperTest.open(session, stillExport: job.export)
        #expect(shell.handle(control: "canvas.template", values: [Double(Self.smallTemplate)]) == .accepted)
        let host = try #require(session.renderHost)
        return (try WallpaperTest.core(shell).project, host.maxRenderSize)
    }

    @Test func aSuccessfulJobPublishesEveryProgressValue() async throws {
        let sink = RecordingAnnouncementSink()
        let job = SaveTest.job("job-success", sink: sink)
        defer { job.export.folder.removeAll() }
        let session = ExperienceSession()
        let (project, maxEdge) = try await openSmall(session, job: job)
        #expect(job.state == .idle && job.progress == 0)

        await job.start(project: project, maxEdge: maxEdge, render: renderer(session))
        let output = try #require(job.output, "\(job.state)")
        #expect(job.progressLog == [0.2, 0.4, 0.7, 0.85, 1.0])
        #expect(job.completedSteps == ExportJob.Step.allCases)
        #expect(job.progress == 1)
        #expect(output.result.width == 750 && output.result.height == 1334)
        #expect(output.url.lastPathComponent == WallpaperExportFile.fileName(project: project, plan: output.plan))
        #expect(job.export.folder.fileCount == 1)
        #expect(sink.announced == ["Exported PNG, 750 × 1334 pixels, sRGB."])
        #expect(job.announcedOutcomes == 1 && job.editor.announcementCount == 1)
        #expect(job.discard())
        #expect(job.export.folder.fileCount == 0)
        session.close()
    }

    @Test func aCancelAfterEachStepLeavesNoFileAndNoGPUResource() async throws {
        let job = SaveTest.job("job-cancel")
        defer { job.export.folder.removeAll() }
        let session = ExperienceSession()
        let (project, maxEdge) = try await openSmall(session, job: job)
        let host = try #require(session.renderHost)
        let live = host.resources.stats.liveCount
        #expect(job.export.folder.fileCount == 0)

        for (index, step) in ExportJob.Step.allCases.enumerated() {
            let before = job.editor.announcementCount
            await job.start(project: project, maxEdge: maxEdge, render: renderer(session), cancelAfter: step)
            #expect(job.state == .cancelled, "\(step)")
            #expect(job.completedSteps.last == step, "\(step)")
            #expect(job.progressLog.count == index + 1, "\(step)")
            #expect(job.export.folder.fileCount == 0, "files after a cancel after \(step)")
            #expect(host.resources.stats.liveCount == live, "GPU after a cancel after \(step)")
            #expect(job.editor.announcementCount == before + 1, "one announcement after \(step)")
            #expect(job.editor.outcome == .failed(EditorModel.cancelledReason), "\(step)")
            #expect(job.shareItem == nil && job.canRetry, "\(step)")
        }

        let frame = try WallpaperTest.picture(session)
        #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "the live picture")
        #expect(host.resources.stats.liveCount == live)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aFailureNamesItsReasonAndRetryUsesTheOfferedPlan() async throws {
        let sink = RecordingAnnouncementSink()
        let job = SaveTest.job("job-retry", sink: sink)
        defer { job.export.folder.removeAll() }
        let session = ExperienceSession()
        let (project, _) = try await openSmall(session, job: job)
        let host = try #require(session.renderHost)
        let live = host.resources.stats.liveCount

        await job.start(project: project, maxEdge: 512, render: renderer(session))
        #expect(job.state == .failed(.doesNotFit))
        #expect(StillExport.FailureReason.doesNotFit.rawValue == "does-not-fit")
        #expect(job.completedSteps.isEmpty, "refused before any rendering")
        let refusal = try #require(job.lastRefusal)
        let offered = try #require(refusal.offeredPlan(format: project.format))
        #expect(offered.fallback && max(offered.width, offered.height) <= 512)
        #expect(job.editor.outcome?.kind == .rejection, "the notice")
        #expect(sink.announced.count == 1, "the notice is announced once")
        #expect(job.export.folder.fileCount == 0)
        #expect(job.canRetry)

        await job.retry()
        let output = try #require(job.output, "\(job.state)")
        #expect(output.plan == offered)
        #expect(output.result.width == offered.width && output.result.height == offered.height)
        #expect(job.progressLog == [0.2, 0.4, 0.7, 0.85, 1.0])
        #expect(job.export.folder.fileCount == 1)
        #expect(host.resources.stats.liveCount == live, "GPU after the retry")
        #expect(job.announcedOutcomes == 2, "the notice, then the written export")
        #expect(job.editor.announcementCount == 2)
        #expect(job.editor.resultLine == "PNG, \(offered.width) × \(offered.height) pixels, sRGB")
        #expect(job.discard())
        #expect(job.export.folder.fileCount == 0)
        session.close()
    }

    @Test func eachOutcomeIsAnnouncedExactlyOnce() async throws {
        let session = ExperienceSession()
        let opener = SaveTest.job("job-announce-open")
        defer { opener.export.folder.removeAll() }
        let (project, maxEdge) = try await openSmall(session, job: opener)
        let closed = ExperienceSession()
        let kinds = ["done", "cancelled", "failed", "notice"]
        for kind in kinds {
            let sink = RecordingAnnouncementSink()
            let job = SaveTest.job("job-announce-" + kind, sink: sink)
            switch kind {
            case "done":
                await job.start(project: project, maxEdge: maxEdge, render: renderer(session))
                #expect(job.editor.outcome?.kind == .outcome)
            case "cancelled":
                await job.start(project: project, maxEdge: maxEdge, render: renderer(session), cancelAfter: .encode)
                #expect(job.editor.outcome == .failed(EditorModel.cancelledReason))
            case "failed":
                await job.start(project: project, maxEdge: maxEdge, render: renderer(closed))
                #expect(job.state == .failed(.render))
                #expect(job.lastRenderError != nil)
                #expect(job.editor.outcome == .failed(StillExport.FailureReason.render.sentence))
            default:
                await job.start(project: project, maxEdge: 512, render: renderer(session))
                #expect(job.editor.outcome?.kind == .rejection)
            }
            #expect(sink.announced.count == 1, "\(kind)")
            #expect(sink.announced == [job.editor.outcome?.text ?? ""], "\(kind)")
            #expect(job.announcedOutcomes == 1 && job.editor.announcementCount == 1, "\(kind)")
            job.discard()
            #expect(job.export.folder.fileCount == 0, "\(kind)")
            job.export.folder.removeAll()
        }
        session.close()
    }
}
