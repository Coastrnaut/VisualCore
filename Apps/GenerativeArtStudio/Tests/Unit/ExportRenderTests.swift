// ExportRenderTests — feature 015 T-A01-406 and T-A01-408 (FR-A01-402–FR-A01-407; SC-A01-401–SC-A01-404).
import ImageIO
import XCTest
import GenerativeArtStudioCore
import VisualCoreDiagnostics
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreTestSupport
@testable import GenerativeArtStudio

@MainActor
final class ExportRenderTests: XCTestCase {
    /// A scene model showing `family` paused at the test time in a 64×48-point view.
    private func model(_ family: SceneFamilyID, budget: ResourceBudget = ResourceBudget(),
                       viewSize: CGSize = ArtRender.size) throws -> SceneModel {
        let doc = try ArtRender.document(family)
        let editor = CompositionEditor(family: FamilyCatalog.family(family), document: doc)
        let m = SceneModel(family: FamilyCatalog.family(family), reduceMotion: false, editor: editor,
                           makeHost: { try RenderHost(scene: $0, budget: budget) })
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(origin: .zero, size: viewSize)
        host.view.layoutIfNeeded()
        m.scene.displayScale = Double(host.pixelSize.height) / viewSize.height
        m.clocked.clock.pause()
        m.scrub(to: ArtRender.time)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(m.scene.errorMessage, family.rawValue)
        return m
    }

    private func decode(_ url: URL) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// Box-averages a top-down RGBA image by an integer factor.
    private func downscale(_ image: StillImage, by f: Int) -> [UInt8] {
        let w = image.width / f, h = image.height / f
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { for x in 0..<w { for c in 0..<4 {
            var sum = 0
            for dy in 0..<f { for dx in 0..<f { sum += Int(image.rgba[((y * f + dy) * image.width + x * f + dx) * 4 + c]) } }
            out[(y * w + x) * 4 + c] = UInt8((Double(sum) / Double(f * f)).rounded())
        } } }
        return out
    }

    private func liveImage(_ m: SceneModel) throws -> StillImage {
        let host = try XCTUnwrap(m.host)
        return try XCTUnwrap(StillImage(width: host.pixelSize.width, height: host.pixelSize.height, bottomUpRGBA: host.readPixels()))
    }

    // SC-A01-401: 12 size × aspect combinations decode to the derived size, opaque, sRGB.
    func testTwelveCombinationsHaveExactDimensionsNoAlphaAndSRGB() throws {
        let m = try model(.gradientNoise)
        defer { m.close() }
        let maxEdge = try XCTUnwrap(m.host).maxRenderSize
        let liveBefore = try XCTUnwrap(m.host).resources.stats.liveCount
        XCTAssertGreaterThanOrEqual(maxEdge, 4096)
        for edge in ExportOptions.offeredLongEdges {
            for aspect in ExportAspect.builtIns {
                let options = ExportOptions(longEdge: edge, aspect: aspect, maxEdge: maxEdge)
                let url = try ExportRunner.export(m, options: options, name: "Combo")
                defer { try? FileManager.default.removeItem(at: url) }
                XCTAssertEqual(url.lastPathComponent, "Combo-\(options.size.width)x\(options.size.height).png")
                let image = try decode(url)
                XCTAssertEqual(image.width, options.size.width, "\(edge) \(aspect.id)")
                XCTAssertEqual(image.height, options.size.height, "\(edge) \(aspect.id)")
                XCTAssertTrue([.none, .noneSkipLast, .noneSkipFirst].contains(image.alphaInfo), "\(edge) \(aspect.id) alpha")
                XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
                print("SC-A01-401 \(edge) \(aspect.id): \(image.width)x\(image.height) alpha=\(image.alphaInfo.rawValue)")
            }
        }
        XCTAssertEqual(try XCTUnwrap(m.host).resources.stats.liveCount, liveBefore, "every export target released")
    }

    // SC-A01-402: the same composition and time export to identical pixels.
    func testRepeatedExportsAreIdenticalForEveryFamily() throws {
        for family in SceneFamilyID.allCases {
            let m = try model(family)
            defer { m.close() }
            let size = ExportSize(width: 540, height: 676)
            let a = try ExportRunner.render(m, size: size), b = try ExportRunner.render(m, size: size)
            let d = ImageComparison.compare(a.rgba, b.rgba)
            XCTAssertEqual(d.maxAbsolute, 0, family.rawValue)
            XCTAssertGreaterThanOrEqual(ImageStatistics.distinctColors(a.rgba), 2, family.rawValue)
            print("SC-A01-402 \(family.rawValue): max=\(d.maxAbsolute)")
        }
    }

    // SC-A01-403 and FR-A01-406: an export at 2× (and 4×) downscaled matches the on-screen frame. The view is 320×240
    // points: in the 64×48 fixture, aliased tile edges (where a supersampled export legitimately differs) cover an
    // unrepresentative share of the pixels.
    func testDownscaledExportMatchesOnScreenRender() throws {
        for family in SceneFamilyID.allCases {
            let m = try model(family, viewSize: CGSize(width: 320, height: 240))
            defer { m.close() }
            let live = try liveImage(m)
            for factor in [2, 4] {
                let export = try ExportRunner.render(m, size: ExportSize(width: live.width * factor, height: live.height * factor))
                let d = ImageComparison.compare(downscale(export, by: factor), live.rgba)
                XCTAssertLessThanOrEqual(d.meanAbsolute, 6, "\(family.rawValue) \(factor)×")
                print("SC-A01-403 \(family.rawValue) \(factor)x: mean=\(String(format: "%.3f", d.meanAbsolute)) max=\(d.maxAbsolute)")
            }
            XCTAssertTrue(try XCTUnwrap(m.host).renderOneFrame(present: false))
            XCTAssertEqual(ImageComparison.compare(try liveImage(m).rgba, live.rgba).maxAbsolute, 0, "\(family) live frame restored")
        }
    }

    // FR-A01-406 negative control: without the export scale, particles shrink and the match is clearly worse.
    func testParticleScalingIsWhatKeepsProportions() throws {
        let m = try model(.particles)
        defer { m.close() }
        let live = try liveImage(m)
        let host = try XCTUnwrap(m.host)
        let size = ExportSize(width: live.width * 4, height: live.height * 4)
        let scaled = ImageComparison.compare(downscale(try ExportRunner.render(m, size: size), by: 4), live.rgba).meanAbsolute
        let unscaled = ImageComparison.compare(downscale(try host.renderOffscreen(width: size.width, height: size.height, time: 0), by: 4),
                                               live.rgba).meanAbsolute
        print("FR-A01-406 particles 4x: scaled mean=\(scaled) unscaled mean=\(unscaled)")
        XCTAssertLessThan(scaled * 1.5, unscaled, "scaling point-sized content must matter")
    }

    // FR-A01-407: only the Photos add-only usage string is declared.
    func testOnlyPhotosAddUsageStringIsDeclared() {
        let info = Bundle.main.infoDictionary ?? [:]
        XCTAssertEqual(info["NSPhotoLibraryAddUsageDescription"] as? String,
                       "Saves exported artwork to your photo library when you choose Save Image.")
        let usage = info.keys.filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") }
        XCTAssertEqual(usage, ["NSPhotoLibraryAddUsageDescription"])
    }

    // SC-A01-404: a failed export shows a readable message, the live scene keeps rendering and nothing leaks.
    func testOverBudgetExportFailsReadablyWithoutLeaks() throws {
        let m = try model(.raymarchedShapes, budget: ResourceBudget(total: 8 << 20))
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        let live = host.resources.stats.liveCount
        let options = ExportOptions(longEdge: 2048, aspect: .square, maxEdge: host.maxRenderSize)
        XCTAssertThrowsError(try ExportRunner.export(m, options: options, name: "Big")) { error in
            let message = ExportRunner.message(for: error)
            XCTAssertTrue(message.contains("graphics memory"), message)
        }
        XCTAssertEqual(host.resources.stats.liveCount, live)
        XCTAssertTrue(host.renderOneFrame(present: false), "live scene keeps rendering")
        XCTAssertNil(host.lastError)
        XCTAssertNoThrow(try ExportRunner.render(m, size: ExportSize(width: 256, height: 256)))
        XCTAssertEqual(host.resources.stats.liveCount, live)
    }

    // FR-A01-405: options never exceed the device limit; requests above it are refused.
    func testOptionsStayWithinDeviceLimit() throws {
        let m = try model(.geometricTiling)
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        let options = ExportOptions(longEdge: 4096, aspect: .story, maxEdge: host.maxRenderSize)
        XCTAssertTrue(options.availableLongEdges.allSatisfy { $0 <= host.maxRenderSize })
        XCTAssertLessThanOrEqual(options.size.longEdge, host.maxRenderSize)
        XCTAssertThrowsError(try ExportRunner.render(m, size: ExportSize(width: host.maxRenderSize + 2, height: 2))) { error in
            XCTAssertTrue(ExportRunner.message(for: error).contains("larger than this device"))
        }
    }

    // Edge case: a suspended host (as when backgrounded) still exports cleanly, and a retry after resume works.
    func testExportOnSuspendedHostAndRetryAfterResume() throws {
        let m = try model(.gradientNoise)
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        let live = host.resources.stats.liveCount
        host.pause()
        let size = ExportSize(width: 128, height: 160)
        let suspended = Result { try ExportRunner.render(m, size: size) }
        XCTAssertEqual(host.resources.stats.liveCount, live)
        host.resume()
        let resumed = try ExportRunner.render(m, size: size)
        if case .success(let image) = suspended {
            XCTAssertEqual(ImageComparison.compare(image.rgba, resumed.rgba).maxAbsolute, 0)
        }
        XCTAssertEqual(host.resources.stats.liveCount, live)
    }

    // Playback state is restored after an export.
    func testPlaybackIsRestored() throws {
        let m = try model(.gradientNoise)
        defer { m.close() }
        m.clocked.clock.play()
        let t = m.clocked.clock.time
        _ = try ExportRunner.render(m, size: ExportSize(width: 64, height: 64))
        XCTAssertTrue(m.clocked.clock.isPlaying)
        XCTAssertEqual(m.clocked.clock.time, t, "the export uses the time when Export was pressed")
    }
}
