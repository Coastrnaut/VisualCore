// ShareFileTests — feature 141 (A19-P04) T-A19-403 (FR-A19-401; clarification Q1; contracts/save.md "Share"). The
// share item of a written export, short runs only (a small plan through a fixed renderer, no host needed; no sleep, no
// wall-clock assertion), each over its own temporary folder (emptied first and removed at the end):
//   - the content type per format (`.png`, `.jpeg`, `.heic`), and the item exports only its own format's type;
//   - the file name "<Scene> <Device> <W>x<H>.<ext>", for example "Ink Flow iPhone 16 Pro 1206x2622.png";
//   - no item without a written file (before an export, after its file is removed, after a cancel);
//   - the item's url is the written file, named as documented, and it exports that file's bytes.
import Foundation
import Testing
import UniformTypeIdentifiers
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the save tests: a renderer that draws one flat colour without a host.
@MainActor
enum SaveTest {
    /// A renderer that returns a flat mid-grey still of the asked size.
    static let flatRender: StillExport.Render = { (width: Int, height: Int, _: Double)
        throws(OffscreenRenderError) -> StillImage in
        let pixels = [UInt8](repeating: 128, count: width * height * 4)
        guard let image = StillImage(width: width, height: height, topDownRGBA: pixels) else {
            throw OffscreenRenderError.unavailable("test")
        }
        return image
    }

    /// A job over a fresh exporter named `name`, announcing through a model with `sink`, recording in `history`.
    static func job(_ name: String, sink: RecordingAnnouncementSink = RecordingAnnouncementSink(),
                    history: HistoryStore? = nil) -> ExportJob {
        ExportJob(export: WallpaperTest.exporter(name), editor: EditorModel(route: EditorTest.route(sink)),
                  history: history)
    }

    /// The default project on the iPhone SE template (750 × 1334) in `format`.
    static func smallProject(_ format: ExportFormat = .png) -> WallpaperProject {
        var project = WallpaperProject.default
        project.template = "iphone-se-3"
        project.format = format
        return project
    }
}

@MainActor
@Suite(.serialized) struct ShareFileTests {
    @Test func theContentTypeFollowsTheFormat() {
        let expected: [ExportFormat: UTType] = [.png: .png, .jpeg: .jpeg, .heic: .heic]
        let url = URL(fileURLWithPath: "/nonexistent/none")
        for format in ExportFormat.allCases {
            let type = expected[format] ?? .data
            let file = WallpaperExportFile(url: url, format: format)
            #expect(WallpaperExportFile.contentType(format) == type, "\(format)")
            #expect(file.contentType == type, "\(format)")
            let exported = file.exportedContentTypes()
            #expect(exported.contains(type), "\(format): \(exported)")
            for other in ExportFormat.allCases where other != format {
                let otherType = expected[other] ?? .data
                #expect(!exported.contains(otherType), "\(format) does not offer \(other)")
            }
        }
    }

    @Test func theFileNameNamesSceneDeviceSizeAndFormat() {
        #expect(WallpaperExportFile.fileName(scene: "Ink Flow", device: "iPhone 16 Pro", width: 1206, height: 2622,
                                             format: .png) == "Ink Flow iPhone 16 Pro 1206x2622.png")
        let ipad = WallpaperExportFile.fileName(scene: "Soft Cells", device: "iPad mini (A17 Pro)", width: 2266,
                                                height: 1488, format: .jpeg)
        #expect(ipad == "Soft Cells iPad mini (A17 Pro) 2266x1488.jpg")
        #expect(WallpaperExportFile.fileName(scene: "A/B", device: "C:D", width: 1, height: 2, format: .heic)
            == "A-B C-D 1x2.heic")
        var project = WallpaperProject.default
        project.scene = "ink-flow"
        project.template = "iphone-16-pro"
        let plan = ExportPlan(format: .png, width: 1206, height: 2622, fallback: false)
        #expect(WallpaperExportFile.fileName(project: project, plan: plan) == "Ink Flow iPhone 16 Pro 1206x2622.png")
    }

    @Test func thereIsNoItemWithoutAWrittenFile() async throws {
        let job = SaveTest.job("share-none")
        defer { job.export.folder.removeAll() }
        #expect(job.shareItem == nil, "before any export")
        #expect(WallpaperExportFile.item(for: nil) == nil)

        await job.start(project: SaveTest.smallProject(), maxEdge: 4096, render: SaveTest.flatRender)
        let output = try #require(job.output)
        #expect(job.shareItem != nil)
        try FileManager.default.removeItem(at: output.url)
        #expect(job.shareItem == nil, "after the file is removed")
        #expect(WallpaperExportFile.item(for: output) == nil)

        await job.start(project: SaveTest.smallProject(), maxEdge: 4096, render: SaveTest.flatRender,
                        cancelAfter: .write)
        #expect(job.state == .cancelled)
        #expect(job.shareItem == nil, "after a cancel")
        #expect(job.export.folder.fileCount == 0)
    }

    @Test func theItemIsTheWrittenFile() async throws {
        let job = SaveTest.job("share-file")
        defer { job.export.folder.removeAll() }
        await job.start(project: SaveTest.smallProject(.jpeg), maxEdge: 4096, render: SaveTest.flatRender)
        let output = try #require(job.output)
        let item = try #require(job.shareItem)
        #expect(item.url == output.url)
        #expect(item.format == .jpeg)
        #expect(item.url.deletingLastPathComponent().standardizedFileURL
            == job.export.folder.url.standardizedFileURL)
        #expect(item.url.lastPathComponent == "Aurora Bands iPhone SE (3rd generation) 750x1334.jpg")
        #expect(FileManager.default.fileExists(atPath: item.url.path))
        #expect(job.export.folder.fileCount == 1)
        let bytes = try await item.exported(as: .jpeg)
        #expect(bytes == (try Data(contentsOf: output.url)), "the share sheet receives the written file")
    }
}
