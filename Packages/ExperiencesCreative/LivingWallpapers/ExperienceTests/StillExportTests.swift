// StillExportTests — feature 139 (A19-P02) T-A19-210 (FR-A19-205; SC-A19-201, SC-A19-202; spec User Stories 2 and 3;
// contracts/experience.md "Export"). The export attempt on the real host inside the one app's session on the
// simulator, short runs only (the iPhone SE template, 750 × 1334, or small plans; no sleep, no wall-clock assertion),
// each exporter over its own temporary folder (emptied first and removed at the end):
//   - every available format exports at a fitting template, verifies and reads back at the planned size tagged sRGB
//     (HEIC's availability is recorded);
//   - two animation times give different files, the same time identical pixels;
//   - the regression fixture: before and after a cancel after render, a cancel after encode, a cancel after write,
//     an oversize failure (maxEdge 512) and a retry at the offered size, the host's live GPU counts and the folder's
//     file count are equal (the retry's file is counted, then discarded); the live picture renders afterwards;
//   - a render that fails (no experience open) fails with the reason `render` and leaves nothing;
//   - the presenter's export through the environment's timed still renderer.
import CoreGraphics
import Foundation
import ImageIO
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering

/// The pixels of the image file at `url` drawn into RGBA bytes (top-down); nil when it cannot be read.
private func decodedPixels(_ url: URL) -> [UInt8]? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return drawn ? pixels : nil
}

@MainActor
@Suite(.serialized) struct StillExportTests {
    /// The index of the iPhone SE (3rd generation) template, 750 × 1334.
    static let smallTemplate = 4

    /// The session's timed still as an export renderer.
    private func renderer(_ session: ExperienceSession) -> StillExport.Render {
        { (width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height, time: time)
        }
    }

    @Test func everyAvailableFormatExportsAtAFittingTemplateAndVerifies() async throws {
        let export = WallpaperTest.exporter("formats")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session, stillExport: export)
        let host = try #require(session.renderHost)
        #expect(shell.handle(control: "canvas.template", values: [Double(Self.smallTemplate)]) == .accepted)
        let heic = StillImageEncoder.isAvailable(.heic)
        print("LivingWallpapers StillExportTests: HEIC available: \(heic)")
        var exported = 0
        for (index, format) in ExportFormat.allCases.enumerated() {
            #expect(shell.handle(control: "export.format", values: [Double(index)]) == .accepted)
            let project = try WallpaperTest.core(shell).project
            #expect(project.format == format)
            let output = export.run(project: project, maxEdge: host.maxRenderSize, render: renderer(session))
            guard StillExport.imageFormat(format).isAvailableHere else {
                #expect(output == nil)
                #expect(export.state == .failed(.formatUnavailable))
                #expect(export.completedSteps.isEmpty, "\(format) refused before rendering")
                continue
            }
            let written = try #require(output, "\(format): \(export.state)")
            #expect(export.state == .written(written.url))
            #expect(export.completedSteps == StillExport.Step.allCases)
            #expect(written.result.width == 750 && written.result.height == 1334, "\(format)")
            #expect(written.result.profileName == ColorProfile.sRGB.name, "\(format)")
            #expect(written.url.pathExtension == StillExport.fileExtension(format))
            let data = try Data(contentsOf: written.url)
            #expect(ImageColorPipeline.verify(data, against: written.plan).isEmpty, "\(format)")
            #expect(data.count == written.result.bytes)
            #expect(export.folder.fileCount == 1, "one file of this exporter at a time")
            exported += 1
        }
        #expect(exported >= 2, "PNG and JPEG are always available")
        session.close()
    }

    @Test func twoAnimationTimesGiveDifferentFilesAndTheSameTimeIdenticalPixels() async throws {
        let export = WallpaperTest.exporter("times")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        _ = try await WallpaperTest.open(session, stillExport: export)
        let plan = ExportPlan(format: .png, width: 90, height: 160, fallback: false)
        var files: [Data] = []
        var pixels: [[UInt8]] = []
        for time in [1.0, 40, 40] {
            let output = try #require(export.run(plan: plan, time: time, render: renderer(session)))
            files.append(try Data(contentsOf: output.url))
            pixels.append(try #require(decodedPixels(output.url)))
        }
        #expect(files[0] != files[1], "two animation times give different files")
        #expect(pixels[0] != pixels[1])
        #expect(pixels[1] == pixels[2], "the same time gives identical pixels")
        session.close()
    }

    @Test func cancellingFailingAndRetryingLeaveNoGPUResourceAndNoFile() async throws {
        let export = WallpaperTest.exporter("cancel-retry")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session, stillExport: export)
        let host = try #require(session.renderHost)
        #expect(shell.handle(control: "canvas.template", values: [Double(Self.smallTemplate)]) == .accepted)
        let project = try WallpaperTest.core(shell).project
        let live = host.resources.stats.liveCount
        let files = export.folder.fileCount
        #expect(files == 0)

        for step in [StillExport.Step.rendered, .encoded, .written] {
            let output = export.run(project: project, maxEdge: host.maxRenderSize, render: renderer(session),
                                    cancelAfter: step)
            #expect(output == nil, "\(step)")
            #expect(export.state == .cancelled, "\(step)")
            #expect(export.completedSteps.last == step, "\(step)")
            #expect(host.resources.stats.liveCount == live, "GPU after a cancel after \(step)")
            #expect(export.folder.fileCount == files, "files after a cancel after \(step)")
        }

        let oversize = export.run(project: project, maxEdge: 512, render: renderer(session))
        #expect(oversize == nil)
        #expect(export.state == .failed(.doesNotFit))
        #expect(export.completedSteps.isEmpty, "refused before any rendering")
        #expect(host.resources.stats.liveCount == live)
        #expect(export.folder.fileCount == files)

        let refusal = try #require(export.lastRefusal)
        let offered = try #require(refusal.offeredPlan(format: project.format))
        #expect(offered.fallback && max(offered.width, offered.height) <= 512)
        let retried = try #require(export.run(plan: offered, time: project.animationTime, render: renderer(session)))
        #expect(retried.result.width == offered.width && retried.result.height == offered.height)
        #expect(retried.result.profileName == ColorProfile.sRGB.name)
        #expect(host.resources.stats.liveCount == live, "GPU after the retry")
        #expect(export.folder.fileCount == files + 1, "the retry's file is handed back")
        #expect(export.discard(retried))
        #expect(export.folder.fileCount == files, "files after the retry is handed on")

        let frame = try WallpaperTest.picture(session)
        #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "the live picture")
        #expect(host.resources.stats.liveCount == live)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aRenderWithNoExperienceOpenFailsAndLeavesNothing() throws {
        let export = WallpaperTest.exporter("no-experience")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        let output = export.run(project: WallpaperProject.default, maxEdge: 4096, render: renderer(session))
        #expect(output == nil)
        #expect(export.state == .failed(.render))
        #expect(export.lastRenderError != nil)
        #expect(export.folder.fileCount == 0)
        #expect(export.run(project: WallpaperProject.default, maxEdge: 0, render: renderer(session)) == nil)
        #expect(export.state == .failed(.noLimit))
    }

    @Test func thePresenterExportsThroughTheTimedStillRenderer() async throws {
        let export = WallpaperTest.exporter("presenter")
        defer { export.folder.removeAll() }
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session, stillExport: export)
        #expect(shell.handle(control: "canvas.template", values: [Double(Self.smallTemplate)]) == .accepted)
        #expect(shell.handle(control: "scene.time", values: [12]) == .accepted)
        _ = try WallpaperTest.picture(session)
        #expect(shell.presenter.maxEdge > 0)
        let timed = ExperienceStillRenderer(timed: { [session] (width: Int, height: Int, time: Double)
            throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height, time: time)
        })
        let output = try #require(shell.presenter.export(using: timed))
        #expect(output.plan.width == 750 && output.plan.height == 1334)
        #expect(WallpaperControls.sentence(output, export: export).hasPrefix("Exported 750 by 1334 pixels, PNG, "))
        #expect(shell.presenter.lastUniformTime == 12, "the export rendered at the animation time")
        session.close()
    }
}

extension StillImageFormat {
    /// Whether ImageIO can write the format on this system (`StillImageEncoder.isAvailable(_:)`).
    fileprivate var isAvailableHere: Bool { StillImageEncoder.isAvailable(self) }
}
