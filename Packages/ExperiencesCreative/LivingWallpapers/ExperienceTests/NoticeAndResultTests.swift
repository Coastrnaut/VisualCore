// NoticeAndResultTests — feature 140 (A19-P03) T-A19-307 (FR-A19-302–304; SC-A19-302; clarifications Q2–Q4;
// contracts/editor.md "Notice", "Result line", "Help"). The editor's model without SwiftUI, short runs only (the
// iPhone SE template, 750 × 1334, or a small offered plan; no sleep, no wall-clock assertion):
//   - at limits 2048, 4096 and 8192 every template above the limit gets `ExportNotice`'s sentence and the offered plan
//     with its "Export at <w> × <h>" title, and every fitting template gets neither; at limit 0 the notice reads
//     "Open a picture to export it.";
//   - a refused export gives the notice as its outcome, no result line, and the help opens from the editor only;
//   - a written export gives `ExportResultLine.line` ("PNG, 750 × 1334 pixels, sRGB") and the help opens from the
//     result too; the offered plan exports through `StillExport.run(plan:time:render:)` at its size;
//   - the help view lays out the three `WallpaperHelp` sections.
import Foundation
import SwiftUI
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the editor tests: a feedback route with a recording sink and fixed renderers.
@MainActor
enum EditorTest {
    /// A route with `sink` that always sees VoiceOver running, at a clock fixed at 0.
    static func route(_ sink: RecordingAnnouncementSink) -> ExperienceFeedback {
        ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: sink, clock: { 0 },
                           voiceOverRunning: { true })
    }

    /// A renderer that always fails.
    static let failingRender: StillExport.Render = { (_: Int, _: Int, _: Double)
        throws(OffscreenRenderError) -> StillImage in
        throw OffscreenRenderError.unavailable("test")
    }

    /// The session's timed still as an export renderer.
    static func renderer(_ session: ExperienceSession) -> ExperienceStillRenderer {
        ExperienceStillRenderer(timed: { [session] (width: Int, height: Int, time: Double)
            throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height, time: time)
        })
    }
}

@MainActor
@Suite(.serialized) struct NoticeAndResultTests {
    /// The index of the iPhone SE (3rd generation) template, 750 × 1334.
    static let smallTemplate = 4

    @Test func theNoticeAndTheOfferedPlanFollowTheLimit() {
        for limit in [2048, 4096, 8192] {
            for template in CanvasTemplates.all {
                var project = WallpaperProject.default
                project.template = template.id
                let planned = ExportPlanner.plan(project: project, maxEdge: limit)
                let notice = EditorModel.notice(planned: planned, limit: limit, orientation: .portrait)
                let offered = EditorModel.offeredPlan(planned: planned, format: .png)
                let size = template.size(for: .portrait)
                guard case .failure(let refusal) = planned else {
                    #expect(notice == nil && offered == nil, "\(template.id) at \(limit)")
                    continue
                }
                #expect(notice == ExportNotice.notice(for: refusal, limit: limit), "\(template.id) at \(limit)")
                let text = notice ?? ""
                #expect(text.contains("\(size.width) × \(size.height)") && text.contains("(\(limit))"),
                        "\(template.id) at \(limit)")
                guard let plan = offered else {
                    Issue.record("\(template.id) at \(limit): no offered plan")
                    continue
                }
                #expect(plan.fallback && plan.format == .png, "\(template.id) at \(limit)")
                #expect(text.contains("\(plan.width) × \(plan.height)"), "\(template.id) at \(limit)")
                #expect(EditorModel.offeredTitle(plan) == "Export at \(plan.width) × \(plan.height)")
            }
        }
        let none = ExportPlanner.plan(project: WallpaperProject.default, maxEdge: 0)
        #expect(EditorModel.notice(planned: none, limit: 0, orientation: .portrait) == "Open a picture to export it.")
        #expect(EditorModel.offeredPlan(planned: none, format: .png) == nil)
    }

    @Test func aRefusedExportGivesTheNoticeAndTheHelpOpensFromTheEditorOnly() {
        let export = WallpaperTest.exporter("notice")
        defer { export.folder.removeAll() }
        let sink = RecordingAnnouncementSink()
        let model = EditorModel(route: EditorTest.route(sink))
        let output = export.run(project: WallpaperProject.default, maxEdge: 2048, render: EditorTest.failingRender)
        #expect(output == nil)
        model.finish(output, export: export, limit: 2048, orientation: .portrait)
        let expected = export.lastRefusal.flatMap { ExportNotice.notice(for: $0, limit: 2048) }
        #expect(expected != nil)
        #expect(model.outcome == expected.map { EditorModel.Outcome.notice($0) })
        #expect(model.outcome?.kind == .rejection)
        #expect(model.resultLine == nil)
        #expect(!model.canOpenHelp(from: .result))
        #expect(!model.openHelp(from: .result))
        #expect(!model.isHelpOpen)
        #expect(model.openHelp(from: .editor))
        #expect(model.helpOrigin == .editor)
        model.closeHelp()
        #expect(!model.isHelpOpen)
        #expect(export.folder.fileCount == 0)
    }

    @Test func aWrittenExportGivesTheResultLineAndTheHelpOpensFromIt() async throws {
        let export = WallpaperTest.exporter("result")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session, stillExport: export)
        #expect(shell.handle(control: "canvas.template", values: [Double(Self.smallTemplate)]) == .accepted)
        _ = try WallpaperTest.picture(session)
        let model = EditorModel(route: EditorTest.route(RecordingAnnouncementSink()))
        let output = try #require(shell.presenter.export(using: EditorTest.renderer(session)))
        model.finish(output, export: export, limit: shell.presenter.maxEdge, orientation: .portrait)
        #expect(model.resultLine == "PNG, 750 × 1334 pixels, sRGB")
        #expect(model.resultLine == ExportResultLine.line(plan: output.plan, result: output.result))
        #expect(model.outcome?.kind == .outcome)
        #expect(model.canOpenHelp(from: .result) && model.canOpenHelp(from: .editor))
        #expect(model.openHelp(from: .result))
        #expect(model.helpOrigin == .result)
        model.closeHelp()

        // The offered plan of a refusal exports at its own size through `run(plan:time:render:)`.
        var project = try WallpaperTest.core(shell).project
        project.format = .png
        guard case .failure(let refusal) = ExportPlanner.plan(project: project, maxEdge: 1024) else {
            Issue.record("the iPhone SE does not fit 1024")
            session.close()
            return
        }
        let offered = try #require(refusal.offeredPlan(format: .png))
        let fallback = try #require(shell.presenter.export(plan: offered, using: EditorTest.renderer(session)))
        #expect(fallback.plan == offered)
        #expect(fallback.result.width == offered.width && fallback.result.height == offered.height)
        model.finish(fallback, export: export, limit: 1024, orientation: .portrait)
        #expect(model.resultLine == "PNG, \(offered.width) × \(offered.height) pixels, sRGB")
        session.close()
    }

    @Test func theHelpViewLaysOutTheThreeSections() throws {
        #expect(WallpaperHelp.sections.count == 3)
        let view = HelpView()
        #expect(view.sections == WallpaperHelp.sections)
        for section in view.sections {
            #expect(!section.title.isEmpty && !section.body.isEmpty)
        }
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 800))
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        let image = try #require(renderer.cgImage)
        #expect(image.width > 0 && image.height > 0)
    }
}
