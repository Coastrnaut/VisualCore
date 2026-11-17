// StillTests — feature 148 (A20-P04) T-A20-405 (FR-A20-405, FR-A20-406; clarification Q4; contracts/library.md
// "Still"). The still picture of the garden for the share sheet: a 1600 × 1200 PNG read back with its size and type;
// one file in the export folder, which a second export replaces; a failed export (no renderer, a renderer that throws
// or draws another size) leaves no file, the previous one included; the garden drawn by the session's own still
// renderer (the path `experienceStillRenderer` hands the controls) gives the PNG through the presenter, with the share
// item and the announcement. Short runs only.
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCorePersistence
import VisualCoreRendering
import VisualCoreUI

/// Still helpers.
@MainActor
enum GardenStillTest {
    /// An exporter writing into its own temporary folder named after `name`, emptied first.
    static func still(_ name: String) -> GardenStill {
        let folder = TemporaryFolder(name: "DigitalZenGarden-StillTests-" + name)
        folder.removeAll()
        return GardenStill(folder: folder)
    }

    /// A renderer drawing a solid picture of `width` × `height` with the grey level `level`.
    static func solid(_ level: UInt8, width: Int = GardenStill.width, height: Int = GardenStill.height)
        -> GardenStill.Render {
        { (_: Int, _: Int) throws(OffscreenRenderError) -> StillImage in
            var rgba = [UInt8](repeating: level, count: width * height * 4)
            for index in stride(from: 3, to: rgba.count, by: 4) { rgba[index] = 255 }
            guard let image = StillImage(width: width, height: height, topDownRGBA: rgba) else { throw .readback }
            return image
        }
    }

    /// The width, height and type identifier of the image file at `url`.
    static func inspect(_ url: URL) -> (width: Int, height: Int, type: String)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height, type)
    }

    /// The written file of `result`; nil for a failure.
    static func url(_ result: Result<URL, StillFailure>) -> URL? {
        if case .success(let url) = result { return url }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct StillTests {
    @Test func aStillIsA1600By1200PNGAndASecondExportReplacesIt() throws {
        let still = GardenStillTest.still("replace")
        defer { still.folder.removeAll() }
        let first = try #require(GardenStillTest.url(still.export(render: GardenStillTest.solid(200))))
        #expect(first.lastPathComponent == "Zen Garden 1600x1200.png" && still.lastURL == first)
        let read = try #require(GardenStillTest.inspect(first))
        #expect(read.width == 1600 && read.height == 1200 && read.type == UTType.png.identifier)
        #expect(still.folder.fileCount == 1)
        let firstData = try Data(contentsOf: first)
        let second = try #require(GardenStillTest.url(still.export(render: GardenStillTest.solid(40))))
        #expect(second == first && still.folder.fileCount == 1)
        #expect(try Data(contentsOf: second) != firstData)
        #expect(GardenStillFile(url: second).url == second)
    }

    @Test func aFailedExportLeavesNoFile() throws {
        let still = GardenStillTest.still("failure")
        defer { still.folder.removeAll() }
        let throwing: GardenStill.Render = { (_: Int, _: Int) throws(OffscreenRenderError) -> StillImage in
            throw OffscreenRenderError.unavailable("test")
        }
        let cases: [(GardenStill.Render?, StillFailure)] = [
            (nil, .noRenderer), (throwing, .render), (GardenStillTest.solid(90, width: 800, height: 600), .render),
        ]
        for (render, expected) in cases {
            #expect(GardenStillTest.url(still.export(render: GardenStillTest.solid(120))) != nil)
            #expect(still.folder.fileCount == 1)
            let result = still.export(render: render)
            #expect(result == .failure(expected), "\(expected)")
            #expect(still.folder.fileCount == 0 && still.lastURL == nil, "\(expected): no file left")
        }
        #expect(StillFailure.allCases.allSatisfy { !$0.sentence.isEmpty })
    }

    @Test func theSessionsStillRendererDrawsTheGardenForTheShareControl() async throws {
        let still = GardenStillTest.still("session")
        defer { still.folder.removeAll() }
        let session = ExperienceSession()
        session.qualityPin = 0
        let id = GardenTest.id
        var made: ExperienceShell<GardenPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = DigitalZenGardenExperience.make(id: id, still: still)
            made = shell
            return shell
        }
        #expect(await session.open(request) == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 120)
        view.layoutIfNeeded()
        try GardenTest.draw(session)
        let shell = try #require(made)
        let sink = RecordingAnnouncementSink()
        shell.presenter.feedback = GardenLibraryTest.route(sink)
        GardenTest.rake(shell, from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.6))
        try GardenTest.draw(session)
        let renderer = ExperienceStillRenderer { (width: Int, height: Int) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height)
        }
        let url = try #require(GardenStillTest.url(shell.presenter.makeStill(renderer: renderer)))
        let read = try #require(GardenStillTest.inspect(url))
        #expect(read.width == 1600 && read.height == 1200 && read.type == UTType.png.identifier)
        #expect(shell.presenter.mirror.stillURL == url && still.folder.fileCount == 1)
        #expect(shell.presenter.mirror.stillMessage == GardenPresenter.stillMadeMessage)
        #expect(sink.announced == [GardenPresenter.stillMadeMessage])
        // Without a renderer the export fails, the file is removed and the share control disappears.
        let failed = shell.presenter.makeStill(renderer: nil)
        #expect(failed == .failure(.noRenderer) && shell.presenter.mirror.stillURL == nil)
        #expect(still.folder.fileCount == 0)
        session.close()
    }
}
