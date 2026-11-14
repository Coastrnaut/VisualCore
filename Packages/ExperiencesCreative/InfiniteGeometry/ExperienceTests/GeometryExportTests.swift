// GeometryExportTests — feature 043 (A05-P04) T-A05-405 (FR-A05-410–413, SC-A05-403). The still export of Infinite
// Geometry through the one app's session host on the simulator, short runs only. For every curated preset: two
// exports at the export size have identical pixels (RGBA, byte for byte) and the exact size, their PNGs decode to the
// same size and to identical pixels; the still at the view's pixel size equals the screen within 2/255 at 16 probe
// pixels away from edges; an export does not change the state digest. A zero-size canvas has no export size, and an
// impossible size throws while the session keeps running. Hosted by the VisualCore app.
import XCTest
import CoreGraphics
import UIKit
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class GeometryExportTests: XCTestCase {
    /// The probe pixels per preset.
    static let probes = 16
    /// The equality tolerance of the still against the screen, in 1/255 steps.
    static let tolerance = 2

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-export-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-export-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func shell(_ experience: (any Experience)?) throws -> ExperienceShell<GeometryPresenter> {
        try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
    }

    /// The still renderer the host view hands to the controls, over `session`.
    private func stillRenderer(_ session: ExperienceSession) -> ExperienceStillRenderer {
        ExperienceStillRenderer { [session] (width: Int, height: Int) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height)
        }
    }

    /// An open, laid-out session (a non-square view) and its experience.
    private func openSession() async throws -> (ExperienceSession, any Experience) {
        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 200, height: 280)
        view.layoutIfNeeded()
        return (session, try XCTUnwrap(made))
    }

    /// The decoded RGBA bytes (top-down rows) and size of a PNG.
    private func decode(_ data: Data) throws -> (rgba: [UInt8], width: Int, height: Int) {
        let image = try XCTUnwrap(UIImage(data: data)?.cgImage, "the PNG decodes")
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        return (rgba, width, height)
    }

    func testExportsAreIdenticalExactlySizedMatchTheScreenAndKeepTheDigest() async throws {
        let (session, experience) = try await openSession()
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        let still = stillRenderer(session)
        for (index, preset) in GeometryPreset.curated.enumerated() {
            let label = "preset \(index) \(GeometryCore.kindName(preset.kind))"
            if try XCTUnwrap(shell(experience).engine.core).presetIndex != index {
                XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(index)]).isAccepted, label)
            }
            for _ in 0..<2 { XCTAssertTrue(host.renderOneFrame(present: false), label) }
            let before = try shell(experience).engine.digest()

            // Screen against the still at the view's pixel size (screen rows bottom-up, still rows top-down).
            let size = host.pixelSize
            let screen = host.readPixels()
            XCTAssertEqual(screen.count, size.width * size.height * 4, label)
            let view = try session.renderStill(width: size.width, height: size.height)
            XCTAssertEqual(view.width, size.width, label)
            XCTAssertEqual(view.height, size.height, label)
            try checkProbes(screen: screen, still: view.rgba, width: size.width, height: size.height, label: label)

            // Two exports at the export size: identical pixels and the exact size.
            let canvas = CGSize(width: size.width, height: size.height)
            let expected = try XCTUnwrap(GeometryExport.size(canvas: canvas, maxEdge: GeometryExport.longEdge), label)
            XCTAssertEqual(max(expected.width, expected.height), GeometryExport.longEdge, label)
            let first = try session.renderStill(width: expected.width, height: expected.height)
            let second = try session.renderStill(width: expected.width, height: expected.height)
            XCTAssertEqual(first.width, expected.width, label)
            XCTAssertEqual(first.height, expected.height, label)
            XCTAssertTrue(first.rgba == second.rgba, "\(label): two stills are identical byte for byte")

            // Two PNG exports decode to the exact size and identical pixels.
            let pngA = try GeometryExport.png(still: still, canvas: canvas, maxEdge: GeometryExport.longEdge)
            let pngB = try GeometryExport.png(still: still, canvas: canvas, maxEdge: GeometryExport.longEdge)
            XCTAssertEqual(pngA.width, expected.width, label)
            XCTAssertEqual(pngA.height, expected.height, label)
            let decodedA = try decode(pngA.data), decodedB = try decode(pngB.data)
            XCTAssertEqual(decodedA.width, expected.width, label)
            XCTAssertEqual(decodedA.height, expected.height, label)
            XCTAssertTrue(decodedA.rgba == decodedB.rgba, "\(label): two exports decode to identical pixels")

            XCTAssertEqual(try shell(experience).engine.digest(), before, "\(label): the export keeps the digest")
            XCTAssertEqual(session.state, .running, label)
        }
    }

    /// 16 probe pixels whose 3 × 3 neighbourhood in the still is uniform (no edge, no antialiasing) must equal the
    /// screen within `tolerance` per channel.
    private func checkProbes(screen: [UInt8], still: [UInt8], width: Int, height: Int, label: String) throws {
        func stillPixel(_ x: Int, _ y: Int) -> ArraySlice<UInt8> { still[((y * width + x) * 4)..<((y * width + x) * 4 + 3)] }
        func screenPixel(_ x: Int, _ yTop: Int) -> ArraySlice<UInt8> {
            let row = height - 1 - yTop
            return screen[((row * width + x) * 4)..<((row * width + x) * 4 + 3)]
        }
        func close(_ a: ArraySlice<UInt8>, _ b: ArraySlice<UInt8>) -> Bool {
            zip(a, b).allSatisfy { abs(Int($0) - Int($1)) <= Self.tolerance }
        }
        var found = 0
        let grid = 24
        outer: for gy in 0..<grid {
            for gx in 0..<grid {
                let x = min(width - 2, max(1, Int((Double(gx) + 0.5) / Double(grid) * Double(width))))
                let y = min(height - 2, max(1, Int((Double(gy) + 0.5) / Double(grid) * Double(height))))
                let centre = stillPixel(x, y)
                var uniform = true
                for dy in -1...1 { for dx in -1...1 where !close(stillPixel(x + dx, y + dy), centre) { uniform = false } }
                guard uniform else { continue }
                XCTAssertTrue(close(screenPixel(x, y), centre),
                              "\(label): pixel \(x), \(y) screen \(Array(screenPixel(x, y))) still \(Array(centre))")
                found += 1
                if found == Self.probes { break outer }
            }
        }
        XCTAssertEqual(found, Self.probes, "\(label): enough uniform probe pixels")
    }

    func testZeroCanvasHasNoSizeAndAnImpossibleSizeThrowsWhileTheSessionKeepsRunning() async throws {
        XCTAssertNil(GeometryExport.size(canvas: .zero, maxEdge: GeometryExport.longEdge))
        XCTAssertNil(GeometryExport.size(canvas: CGSize(width: 100, height: 0), maxEdge: GeometryExport.longEdge))
        XCTAssertNil(GeometryExport.size(canvas: CGSize(width: CGFloat.nan, height: 10), maxEdge: GeometryExport.longEdge))
        let wide = try XCTUnwrap(GeometryExport.size(canvas: CGSize(width: 100_000, height: 10), maxEdge: 2048))
        XCTAssertEqual(wide.width, 2048)
        XCTAssertEqual(wide.height, 1, "at least one pixel on each side")
        let small = try XCTUnwrap(GeometryExport.size(canvas: CGSize(width: 300, height: 200), maxEdge: 600))
        XCTAssertEqual(small.width, 600)
        XCTAssertEqual(small.height, 400)

        let (session, experience) = try await openSession()
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let before = try shell(experience).engine.digest()
        let still = stillRenderer(session)
        XCTAssertThrowsError(try GeometryExport.png(still: still, canvas: .zero, maxEdge: GeometryExport.longEdge))
        // GeometryExport never asks for more than 2048 pixels, so the failure path of an impossible size is the still
        // renderer's own refusal, which GeometryExport.png passes on unchanged.
        XCTAssertThrowsError(try still(width: 100_000, height: 10), "a 100 000-pixel edge cannot be rendered")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell(experience).engine.digest(), before)
        XCTAssertTrue(host.renderOneFrame(present: false), "the session keeps drawing")
        let capture = try GeometryExport.png(still: still, canvas: CGSize(width: 300, height: 200), maxEdge: 600)
        XCTAssertEqual(capture.width, 600)
        XCTAssertEqual(capture.height, 400)
        XCTAssertEqual(try decode(capture.data).width, 600)
    }
}
