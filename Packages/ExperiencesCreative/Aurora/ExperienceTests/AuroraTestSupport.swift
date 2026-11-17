// AuroraTestSupport — feature 153 (A21-P02) T-A21-204 (FR-A21-201–207; SC-A21-201–204). Shared helpers of the Aurora
// experience tests: an engine and a shell without a render host (prepared and active, so actions are carried out with
// no frame drawn), opening the experience in the one app's session host, drawing frames, drawing an off-screen still
// at the reference size (64 × 48, rows top-down, the same orientation as `SkyReference`), comparing pictures and
// measuring luminance, and the engine digest of a core. Feature 154 (A21-P03): the reference of a mixed frame during a
// change between presets (both skies' references mixed in display space), opening with a storage and a snapshot, and
// a temporary storage. Feature 155 (A21-P04): opening with the system's Reduce Flashing and a hook that configures the
// presenter before its first `setup` (the fallback seams), frames at 30 per second, the window's mean luminance and
// the GPU bytes held. Feature 156 (A21-P05): opening with a loop factory (a fake player). Short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import UIKit
import AuroraCore
@testable import AuroraExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Aurora.
@MainActor
enum AuroraTest {
    /// The experience id `a21.aurora`.
    static var id: ExperienceID {
        AuroraExperience.id ?? ExperienceID(rawValue: "a21.unknown")!
    }

    /// The reference size of the stills: 64 × 48 pixels.
    static let width = 64, height = 48

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<SkyCore> {
        var engine = ExperienceEngine<SkyCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host.
    static func shell(reduceMotion: Bool = false) async throws -> ExperienceShell<AuroraPresenter> {
        let shell = AuroraExperience.make(id: id, reduceMotion: reduceMotion)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<AuroraPresenter>) throws -> SkyCore {
        try #require(shell.engine.core)
    }

    /// Opens Aurora in `session` through the factory (with `storage` and the session `snapshot` when given), lays
    /// the view out at `size` points and draws one frame. A session without a quality pin is pinned to level 0.
    /// `reduceFlashing` is the system's Reduce Flashing; `configure` runs on the presenter before its first `setup`;
    /// `loopFactory` (after `configure`, so a trailing closure stays `configure`) makes the sound's player (nil: the
    /// ambient loop player).
    static func open(_ session: ExperienceSession, reduceMotion: Bool = false,
                     size: CGSize = CGSize(width: 32, height: 24), storage: ExperienceStorage? = nil,
                     snapshot: ExperienceSnapshot? = nil, reduceFlashing: Bool = false,
                     configure: ((AuroraPresenter) -> Void)? = nil,
                     loopFactory: (() -> any SkyLoopPlaying)? = nil) async throws -> ExperienceShell<AuroraPresenter> {
        let id = self.id
        var made: ExperienceShell<AuroraPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: snapshot,
                                            refusedSnapshotFails: snapshot != nil) {
            let shell = AuroraExperience.make(id: id, reduceMotion: reduceMotion, storage: storage,
                                              reduceFlashing: reduceFlashing, loopFactory: loopFactory)
            configure?(shell.presenter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        try draw(session)
        return shell
    }

    /// Draws `count` frames of `session` (each 1/60 s of frame time).
    static func draw(_ session: ExperienceSession, frames count: Int = 1) throws {
        let host = try #require(session.renderHost)
        var drawn = 0
        for _ in 0..<count where host.renderOneFrame(present: false) { drawn += 1 }
        #expect(drawn == count)
    }

    /// Draws one frame of 1/30 s (two host frames of 1/60 s each), the frame interval at 30 frames per second.
    static func drawAt30(_ session: ExperienceSession) throws {
        try draw(session, frames: 2)
    }

    /// The live bytes of textures, buffers, framebuffers and renderbuffers (render targets) held by `session`'s host.
    static func targetBytes(_ session: ExperienceSession) throws -> [ResourceKind: Int] {
        let stats = try #require(session.renderHost).resources.stats
        var bytes: [ResourceKind: Int] = [:]
        for kind in [ResourceKind.texture, .buffer, .framebuffer, .renderbuffer] {
            bytes[kind] = stats.liveBytes[kind] ?? 0
        }
        return bytes
    }

    /// An off-screen still of `session` at `width` × `height` (frame delta 0: the clock and the blend stay), RGBA8
    /// rows top-down.
    static func still(_ session: ExperienceSession, width: Int = width, height: Int = height) throws -> [UInt8] {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: 0).rgba
    }

    /// The reference drawing of the presenter's last frame at `width` × `height`: the last uniforms' sky, or during a
    /// change with a moving outgoing sky the two skies' references mixed in display space at the mix drawn (the
    /// crossfade's `mix(from, to, progress)` of 8-bit pictures).
    static func reference(_ shell: ExperienceShell<AuroraPresenter>, width: Int = width,
                          height: Int = height) throws -> [UInt8] {
        let presenter = shell.presenter
        let uniforms = try #require(presenter.lastUniforms)
        let incoming = SkyReference.render(uniforms, width: width, height: height)
        guard let mix = presenter.lastMix, let outgoingUniforms = presenter.lastOutgoingUniforms else { return incoming }
        let outgoing = SkyReference.render(outgoingUniforms, width: width, height: height)
        return mixed(outgoing, incoming, mix)
    }

    /// `a × (1 − t) + b × t` per channel, rounded to 8 bits.
    static func mixed(_ a: [UInt8], _ b: [UInt8], _ t: Double) -> [UInt8] {
        guard a.count == b.count else { return b }
        var out = [UInt8](repeating: 0, count: a.count)
        for i in 0..<a.count {
            out[i] = UInt8(min(max((Double(a[i]) * (1 - t) + Double(b[i]) * t).rounded(), 0), 255))
        }
        return out
    }

    /// A fresh storage of Aurora in a temporary folder and its own defaults suite; `cleanUp` removes both.
    static func storage() throws -> (storage: ExperienceStorage, defaults: UserDefaults, cleanUp: () -> Void) {
        let name = "aurora-tests-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults = try #require(UserDefaults(suiteName: name))
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        return (storage, defaults, {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: root)
        })
    }

    /// Sends `control` with `values` through `shell` and records an issue unless it is accepted (keeps the mutating
    /// call outside `#expect`).
    @discardableResult
    static func accept(_ shell: ExperienceShell<AuroraPresenter>, _ control: String, _ values: [Double],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.handle(control: control, values: values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    /// Mean and largest absolute difference of the colour channels, in 8-bit steps.
    static func difference(_ a: [UInt8], _ b: [UInt8]) -> (mean: Double, max: Int) {
        guard a.count == b.count, !a.isEmpty else { return (.infinity, .max) }
        var sum = 0, largest = 0
        var i = 0
        while i + 3 < a.count {
            for c in 0..<3 {
                let d = abs(Int(a[i + c]) - Int(b[i + c]))
                sum += d
                largest = max(largest, d)
            }
            i += 4
        }
        return (Double(sum) / Double(a.count / 4 * 3), largest)
    }

    /// The largest and mean Rec. 709 luminance of the sRGB-decoded pixels.
    static func luminance(_ rgba: [UInt8]) -> (max: Float, mean: Float) {
        var largest: Float = 0, sum: Float = 0
        var i = 0
        while i + 3 < rgba.count {
            let l = SkyReference.luminance(rgba: rgba, index: i)
            largest = max(largest, l)
            sum += l
            i += 4
        }
        return (largest, sum / Float(max(rgba.count / 4, 1)))
    }

    /// Sends one pointer event of pointer `id` at `location` (view points) to `shell` in a 320 × 240 view.
    static func touch(_ shell: ExperienceShell<AuroraPresenter>, _ phase: PointerPhase, at location: Vec2,
                      id: Int = 1) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: 0),
                            viewSize: Vec2(320, 240))
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func skyDigest(_ core: SkyCore) throws -> String {
    var builder = DigestBuilder(domain: SkyCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func skyApplied(_ core: SkyCore, _ control: String, _ values: [Double]) -> (SkyCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
