// EditorAccessibilityTests — feature 140 (A19-P03) T-A19-309 (FR-A19-305; SC-A19-303; clarification Q5;
// contracts/editor.md "Accessibility"). The editor's accessibility without a system audit (audits wait for the device
// campaign, owner ruling of 2026-11-13), short runs only:
//   - every control's label (`EditorModel.labels`) is non-empty, names its value and reads "<title>, <value>", in
//     every scene, with edited colours, the offered export and the result's help button, for example
//     "Scene, Ink Flow" and "Colour 2, red 0.40, green 0.20, blue 0.60";
//   - each export outcome (done, failed, no renderer, the notice) gives exactly one announcement through a recording
//     sink, of kind `.outcome` for done or failed and `.rejection` for the notice;
//   - at the accessibility-five Dynamic Type size the controls, rendered with `ImageRenderer` at a proposed width of
//     390 points, are no wider than 390 points, and they stack (taller than at the large size).
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

@MainActor
@Suite(.serialized) struct EditorAccessibilityTests {
    /// The width of the canvas the controls must fit, points.
    static let canvasWidth: CGFloat = 390

    /// The labels of `core` (followed into a presenter's mirror) with `offered` and `resultLine`.
    static func labels(_ core: WallpaperCore, offered: ExportPlan? = nil, resultLine: String? = nil) -> [EditorLabel] {
        let presenter = WallpaperPresenter()
        presenter.follow(core)
        return EditorModel.labels(presenter.mirror, offeredPlan: offered, resultLine: resultLine)
    }

    @Test func everyLabelIsNonEmptyAndNamesItsValue() {
        let offered = ExportPlan(format: .png, width: 942, height: 2048, fallback: true)
        for scene in 0..<SceneCatalog.scenes.count {
            var core = WallpaperCore()
            for (control, values) in [("scene.select", [Double(scene)]), ("preset.color", [1, 0.4, 0.2, 0.6]),
                                      ("canvas.orientation", [1])] {
                _ = core.apply(ExperienceAction(control: control, values: values, step: 0))
            }
            let labels = Self.labels(core, offered: offered, resultLine: "PNG, 942 × 2048 pixels, sRGB")
            let parameters = SceneCatalog.scenes[scene].parameters.count
            #expect(labels.count == 16 + parameters, "scene \(scene)")
            #expect(Set(labels.map(\.name)).count == labels.count, "scene \(scene): unique names")
            for label in labels {
                #expect(!label.title.isEmpty && !label.value.isEmpty, "\(label.name)")
                #expect(label.text == label.title + ", " + label.value, "\(label.name)")
                #expect(label.text.contains(label.value), "\(label.name)")
            }
            let byName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0.text) })
            #expect(byName["scene"] == "Scene, " + SceneCatalog.scenes[scene].name)
            #expect(byName["colour-1"] == "Colour 2, red 0.40, green 0.20, blue 0.60")
            #expect(byName["orientation"] == "Orientation, Landscape")
            #expect(byName["export-offered"] == "Export at 942 × 2048, PNG, 942 × 2048 pixels")
        }
        let plain = Self.labels(WallpaperCore())
        let names = plain.map(\.name)
        #expect(!names.contains("export-offered") && !names.contains("result-help"))
        let byName = Dictionary(uniqueKeysWithValues: plain.map { ($0.name, $0.text) })
        #expect(byName["preset"] == "Colours, Polar Night")
        #expect(byName["parameter-0"] == "Bands, 4.00")
        #expect(byName["time"] == "Moment, 0.0 seconds")
        #expect(byName["motion"] == "Motion, On")
        #expect(byName["export"] == "Export, PNG, 1206 × 2622 pixels")
    }

    @Test func eachExportOutcomeIsAnnouncedExactlyOnce() async throws {
        let export = WallpaperTest.exporter("announce")
        defer { export.folder.removeAll() }
        let written = StillExport.Output(
            url: export.folder.url.appendingPathComponent("none.png"),
            result: ExportResult(width: 750, height: 1334, profileName: "kCGColorSpaceSRGB", bytes: 1),
            plan: ExportPlan(format: .png, width: 750, height: 1334, fallback: false))
        let shell = try await WallpaperTest.shell()
        let failed = ExperienceSession()
        let render: StillExport.Render = { (width: Int, height: Int, time: Double)
            throws(OffscreenRenderError) -> StillImage in
            try failed.renderStill(width: width, height: height, time: time)
        }
        let kinds: [String] = ["done", "failed", "no-renderer", "notice"]
        for kind in kinds {
            let sink = RecordingAnnouncementSink()
            let model = EditorModel(route: EditorTest.route(sink))
            switch kind {
            case "done":
                model.finish(written, export: export, limit: 4096, orientation: .portrait, port: shell.port)
                #expect(model.outcome?.kind == .outcome)
            case "failed":
                let output = export.run(project: WallpaperProject.default, maxEdge: 4096, render: render)
                #expect(output == nil && export.state == .failed(.render))
                model.finish(output, export: export, limit: 4096, orientation: .portrait)
                #expect(model.outcome == .failed(StillExport.FailureReason.render.sentence))
                #expect(model.outcome?.kind == .outcome)
            case "no-renderer":
                model.finishWithoutRenderer(port: shell.port)
                #expect(model.outcome?.kind == .outcome)
            default:
                let output = export.run(project: WallpaperProject.default, maxEdge: 2048, render: render)
                model.finish(output, export: export, limit: 2048, orientation: .portrait)
                #expect(model.outcome?.kind == .rejection)
            }
            #expect(sink.announced.count == 1, "\(kind)")
            #expect(sink.announced == [model.outcome?.text ?? ""], "\(kind)")
            #expect(model.announcementCount == 1, "\(kind)")
        }
    }

    @Test func atAccessibilityFiveTheControlsStackWithinTheCanvas() async throws {
        let shell = try await WallpaperTest.shell()
        let presenter = shell.presenter
        presenter.follow(try WallpaperTest.core(shell))
        presenter.editor.record(.done("PNG, 1206 × 2622 pixels, sRGB"))
        func rendered(_ size: DynamicTypeSize) throws -> CGImage {
            let controls = WallpaperControls(port: shell.port, mirror: presenter.mirror, presenter: presenter,
                                             model: presenter.editor)
                .environment(\.dynamicTypeSize, size)
            let renderer = ImageRenderer(content: controls)
            renderer.proposedSize = ProposedViewSize(width: Self.canvasWidth, height: nil)
            renderer.scale = 1
            return try #require(renderer.cgImage)
        }
        let large = try rendered(.large)
        let largest = try rendered(.accessibility5)
        #expect(CGFloat(largest.width) <= Self.canvasWidth, "width \(largest.width) at accessibility-five")
        #expect(CGFloat(large.width) <= Self.canvasWidth, "width \(large.width) at large")
        #expect(largest.height > large.height, "the rows stack at accessibility-five")
    }
}
