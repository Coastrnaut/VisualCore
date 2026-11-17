// WallpaperTestSupport — feature 139 (A19-P02) T-A19-208, T-A19-210 (FR-A19-203–206; SC-A19-201–204). Shared helpers
// of the Living Wallpapers experience tests: an engine and a shell without a render host (prepared and active, so
// actions are carried out with no frame drawn), opening the experience in the one app's session host, drawing and
// reading frames, offscreen stills at a frame time, an exporter over a private temporary folder, pixel comparison and
// the engine digest of a core.
import Foundation
import Testing
import UIKit
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias WallpaperFrame = (rgba: [UInt8], width: Int, height: Int)

/// Building, opening, drawing and reading Living Wallpapers.
@MainActor
enum WallpaperTest {
    /// The experience id `a19.living-wallpapers`.
    static var id: ExperienceID {
        LivingWallpapersExperience.id ?? ExperienceID(rawValue: "a19.unknown")!
    }

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<WallpaperCore> {
        var engine = ExperienceEngine<WallpaperCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host.
    static func shell(reduceMotion: Bool = false) async throws -> ExperienceShell<WallpaperPresenter> {
        let shell = LivingWallpapersExperience.make(id: id, reduceMotion: reduceMotion)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<WallpaperPresenter>) throws -> WallpaperCore {
        try #require(shell.engine.core)
    }

    /// An exporter over a fresh private folder named `name` (emptied first).
    static func exporter(_ name: String) -> StillExport {
        let folder = TemporaryFolder(name: "LivingWallpapers-Test-" + name)
        folder.removeAll()
        return StillExport(folder: folder)
    }

    /// Opens Living Wallpapers in `session` through the factory (with `reduceMotion` and `stillExport`), lays the
    /// view out at `size` points and draws one frame. A session without a quality pin is pinned to level 0.
    static func open(_ session: ExperienceSession, reduceMotion: Bool = false,
                     stillExport: StillExport = StillExport(),
                     size: CGSize = CGSize(width: 120, height: 200)) async throws
        -> ExperienceShell<WallpaperPresenter> {
        let id = self.id
        var made: ExperienceShell<WallpaperPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = LivingWallpapersExperience.make(id: id, reduceMotion: reduceMotion, stillExport: stillExport)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return shell
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> WallpaperFrame {
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The scene drawn offscreen at `width` × `height` pixels at frame time `time` (rows top-down).
    static func still(_ session: ExperienceSession, time: Double, width: Int = 64, height: Int = 96) throws
        -> StillImage {
        try session.renderStill(width: width, height: height, time: time)
    }

    /// The number of pixels whose RGB differs in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] { count += 1 }
            i += 4
        }
        return count
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func wallpaperDigest(_ core: WallpaperCore) throws -> String {
    var builder = DigestBuilder(domain: WallpaperCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func wallpaperApplied(_ core: WallpaperCore, _ control: String, _ values: [Double]) -> (WallpaperCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
