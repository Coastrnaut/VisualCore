// SamplePresenter — feature 188 (UA-F02) T-U02-035 (data-model section 7; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). The presenter of the sample experience
// `a99.contract-sample` and the helpers the three shell test files share. Test-only.
import SwiftUI
import UIKit
import CVisualCoreGL
import VisualCoreRendering
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreTestSupport

/// The error the sample presenter throws when a test asks it to fail.
struct SamplePresenterError: Error, Equatable {
    /// `setup` or `draw`.
    let stage: String
}

/// Draws the sample: one 1 × 1 texture through the registry and a clear to (x / 15, y / 15, tone, 1). It counts
/// every call, so that tests can prove what reached it and what did not.
@MainActor
final class SamplePresenter<Fault: SampleFault>: ExperiencePresenter {
    typealias Core = SampleExperienceCore<Fault>

    // MARK: Counters

    private(set) var setupCalls = 0
    private(set) var resizeCalls = 0
    private(set) var drawCalls = 0
    private(set) var teardownCalls = 0
    private(set) var shedCalls = 0
    private(set) var controlsCalls = 0
    /// The tier of the last `draw`; nil before the first one.
    private(set) var lastTier: Int?
    /// The port the last `makeControls` received.
    private(set) var lastControlsPort: ExperienceActionPort?
    /// The texture of the current context; kept after `teardown` only when `keepsTextureOnTeardown` is set.
    private(set) var texture: Texture?

    // MARK: Switches

    /// `setup` throws before it creates anything.
    var failsInSetup = false
    /// `draw` throws before it draws anything.
    var failsInDraw = false
    /// `teardown` does not release the texture (a deliberate leak).
    var keepsTextureOnTeardown = false
    /// `draw` clears to black and nothing else (a blank frame; feature 195).
    var drawsBlank = false
    /// The class the centre probe declares instead of the true one (a wrong probe; feature 195).
    var wrongProbe: String?
    /// `draw` adds a mark in the contrasting grey to the lower-left corner, so that the frame is never one colour
    /// (feature 195, the non-blank check). Off by default: a scissored clear on every frame grows the memory
    /// footprint on the iOS 26.5 simulator (observed 2026-11-12 with the UA-F06 endurance test: 9.3 MB over
    /// 36,000 frames, flat without it), so only the verification tests turn it on.
    var marksCorner = false

    init() {}

    // MARK: ExperiencePresenter

    func setup(_ context: RenderContext) throws {
        setupCalls += 1
        if failsInSetup { throw SamplePresenterError(stage: "setup") }
        texture = try context.resources.makeTexture(width: 1, height: 1, label: "sample")
    }

    func resize(_ context: RenderContext) {
        resizeCalls += 1
    }

    func draw(_ core: SampleExperienceCore<Fault>, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        drawCalls += 1
        lastTier = tier
        if failsInDraw { throw SamplePresenterError(stage: "draw") }
        if drawsBlank {
            vcglClearColor(0, 0, 0, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            return
        }
        vcglClearColor(Float(core.x) / 15, Float(core.y) / 15, Float(core.tone), 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard marksCorner else { return }
        // A corner mark in the contrasting grey, so that the frame is never one colour (feature 195, FR-U09-040).
        let light = (0.2126 * Double(core.x) / 15 + 0.7152 * Double(core.y) / 15 + 0.0722 * core.tone) > 0.5
        let mark: Float = light ? 0 : 1
        vcglEnable(GLenum(GL_SCISSOR_TEST))
        vcglScissor(0, 0, GLsizei(max(1, context.pixelWidth / 4)), GLsizei(max(1, context.pixelHeight / 4)))
        vcglClearColor(mark, mark, mark, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        vcglDisable(GLenum(GL_SCISSOR_TEST))
    }

    func teardown(_ context: RenderContext) {
        teardownCalls += 1
        guard !keepsTextureOnTeardown, let texture else { return }
        context.resources.release(texture)
        self.texture = nil
    }

    func shedCaches() {
        shedCalls += 1
    }

    /// The centre of the frame shows the state's colour class (feature 195).
    func probes(_ core: SampleExperienceCore<Fault>) -> [FrameProbe] {
        let pixel = expectedPixel(for: core)
        let expected = FrameChecks.classify(r: UInt8(pixel.0), g: UInt8(pixel.1), b: UInt8(pixel.2)).rawValue
        return [FrameProbe(name: "centre", x: 0.5, y: 0.5, expected: wrongProbe ?? expected)].compactMap { $0 }
    }

    func describe(_ core: SampleExperienceCore<Fault>) -> String {
        "marker at \(core.x), \(core.y), tone \(String(format: "%.2f", core.tone))"
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        controlsCalls += 1
        lastControlsPort = port
        return AnyView(Button("Ping") { port.send("ping") }.accessibilityIdentifier(port.identifier("ping")))
    }
}

// MARK: - Shared helpers

/// The shell of the sample without a fault.
typealias SampleShell = ExperienceShell<SamplePresenter<NoFault>>
/// The pure engine of the sample without a fault, for comparisons with the shell.
typealias SampleEngine = ExperienceEngine<SampleExperienceCore<NoFault>>
/// One pixel as 0…255 per channel.
typealias SamplePixel = (r: Int, g: Int, b: Int, a: Int)

/// A new presenter and its shell in the state registered.
@MainActor
func makeSampleShell<Fault: SampleFault>(
    _ fault: Fault.Type = NoFault.self
) -> (presenter: SamplePresenter<Fault>, shell: ExperienceShell<SamplePresenter<Fault>>) {
    let presenter = SamplePresenter<Fault>()
    return (presenter, ExperienceShell(id: SampleExperience.id, presenter: presenter))
}

/// A presenter and its shell, prepared with `seed` (state ready).
@MainActor
func makeReadySampleShell(seed: UInt64 = 42) async throws -> (presenter: SamplePresenter<NoFault>, shell: SampleShell) {
    let made = makeSampleShell(NoFault.self)
    try await made.shell.prepare(seed: seed, timeLimit: nil)
    return made
}

/// A render host of 64 × 64 points, laid out off screen (the pattern of RenderHostTests).
@MainActor
func makeLaidOutHost(_ scene: any RenderScene) throws -> RenderHost {
    let host = try RenderHost(scene: scene)
    host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
    host.view.layoutIfNeeded()
    return host
}

/// The pixel at the centre of the host's window surface; (-1, -1, -1, -1) without a surface.
@MainActor
func centrePixel(of host: RenderHost) -> SamplePixel {
    let pixels = host.readPixels()
    let size = host.pixelSize
    let index = ((size.height / 2) * size.width + size.width / 2) * 4
    guard size.width > 0, size.height > 0, index + 3 < pixels.count else { return (-1, -1, -1, -1) }
    return (Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]), Int(pixels[index + 3]))
}

/// The pixel the sample presenter draws for `core`: (x · 255 / 15, y · 255 / 15, tone · 255, 255).
func expectedPixel<Fault: SampleFault>(for core: SampleExperienceCore<Fault>) -> SamplePixel {
    (Int((Double(core.x) * 255 / 15).rounded()), Int((Double(core.y) * 255 / 15).rounded()),
     Int((core.tone * 255).rounded()), 255)
}

/// Whether every channel of `found` lies within `tolerance` of `expected`.
func pixelsMatch(_ found: SamplePixel, _ expected: SamplePixel, tolerance: Int = 2) -> Bool {
    abs(found.r - expected.r) <= tolerance && abs(found.g - expected.g) <= tolerance
        && abs(found.b - expected.b) <= tolerance && abs(found.a - expected.a) <= tolerance
}

/// Whether the centre pixel of `host` shows the state of the shell's core; false without a core.
@MainActor
func centreShowsState<Fault: SampleFault>(_ host: RenderHost,
                                          _ shell: ExperienceShell<SamplePresenter<Fault>>) -> Bool {
    guard let core = shell.engine.core else { return false }
    return pixelsMatch(centrePixel(of: host), expectedPixel(for: core))
}

/// The `ExperienceError` that `body` throws; nil when it throws nothing or something else.
@MainActor
func refusal(_ body: () throws -> Void) -> ExperienceError? {
    do {
        try body()
        return nil
    } catch {
        return error as? ExperienceError
    }
}

/// The `ExperienceError` that the asynchronous `body` throws; nil when it throws nothing or something else.
@MainActor
func asyncRefusal(_ body: () async throws -> Void) async -> ExperienceError? {
    do {
        try await body()
        return nil
    } catch {
        return error as? ExperienceError
    }
}

/// Waits, in slices of 5 ms and without blocking the main actor, until `condition` holds. False after `timeout`.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
