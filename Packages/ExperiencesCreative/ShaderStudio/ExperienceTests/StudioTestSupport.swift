// StudioTestSupport — feature 160 (A22-P02) T-A22-205 (SC-A22-201–204). Shared helpers of the Shader Studio
// experience tests: an engine and a shell without a render host (prepared and active, so actions are carried out with
// no frame drawn), opening the experience in the one app's session host, drawing frames, drawing an off-screen still
// (frame time 0, so `u_time` is 0 and the picture depends only on the shader and its uniforms), comparing pictures,
// sources that fail to compile or link, and the engine digest of a core. Short runs only (no sleep, no wall-clock
// assertion).
import CoreGraphics
import Foundation
import Testing
import UIKit
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// Building, opening, drawing and reading back Shader Studio.
@MainActor
enum StudioTest {
    /// The experience id `a22.shader-studio`.
    static var id: ExperienceID {
        ShaderStudioExperience.id ?? ExperienceID(rawValue: "a22.unknown")!
    }

    /// The size of the stills: 32 × 24 pixels.
    static let width = 32, height = 24

    /// A source that fails to compile on its fourth line (an undeclared name), declaring `u_speed` (the Gradient
    /// template's uniform) so the validator accepts it.
    static let brokenSource = """
    // Broken on line 4.
    uniform float u_speed;
    void main() {
        fragColor = vec4(undefinedThing * u_speed, 0.0, 0.0, 1.0);
    }

    """
    /// The authored line of ``brokenSource``'s error.
    static let brokenLine = 4

    /// A source that compiles and draws a flat colour different from every template (keeps `u_speed`).
    static let fixedSource = """
    // Fixed: a flat colour scaled by the speed.
    uniform float u_speed;
    void main() {
        fragColor = vec4(0.9, 0.1 * u_speed, 0.6, 1.0);
    }

    """

    /// A source the validator refuses (a `#version` line on line 1).
    static let refusedSource = """
    #version 300 es
    uniform float u_speed;
    void main() { fragColor = vec4(u_speed); }

    """

    /// A source that compiles per stage but fails to link: it reads an input the vertex shader does not write.
    static let linkFailureSource = """
    // Reads an input the full-screen vertex shader never writes: the linker refuses it.
    uniform float u_speed;
    in vec2 v_extra;
    void main() {
        fragColor = vec4(v_extra * u_speed, 0.0, 1.0);
    }

    """

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<StudioCore> {
        var engine = ExperienceEngine<StudioCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host.
    static func shell() async throws -> ExperienceShell<StudioPresenter> {
        let shell = ShaderStudioExperience.make(id: id)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<StudioPresenter>) throws -> StudioCore {
        try #require(shell.engine.core)
    }

    /// Opens Shader Studio in `session` through the factory, lays the view out at `size` points and draws one
    /// frame. A session without a quality pin is pinned to level 0.
    static func open(_ session: ExperienceSession,
                     size: CGSize = CGSize(width: 32, height: 24)) async throws -> ExperienceShell<StudioPresenter> {
        let id = self.id
        var made: ExperienceShell<StudioPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = ShaderStudioExperience.make(id: id)
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

    /// Draws `count` frames of `session`.
    static func draw(_ session: ExperienceSession, frames count: Int = 1) throws {
        let host = try #require(session.renderHost)
        var drawn = 0
        for _ in 0..<count where host.renderOneFrame(present: false) { drawn += 1 }
        #expect(drawn == count)
    }

    /// An off-screen still of `session` at `width` × `height` (frame time 0), RGBA8 rows top-down. The still is a
    /// draw of the presenter, so a pending request is compiled by it.
    static func still(_ session: ExperienceSession, width: Int = width, height: Int = height) throws -> [UInt8] {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: 0).rgba
    }

    /// Sends `control` with `values` through `shell` and records an issue unless it is accepted.
    @discardableResult
    static func accept(_ shell: ExperienceShell<StudioPresenter>, _ control: String, _ values: [Double],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.handle(control: control, values: values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    /// Sets `source` as the document's source and runs it at the next frame (draws one frame).
    static func run(_ session: ExperienceSession, _ shell: ExperienceShell<StudioPresenter>, source: String,
                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(shell.presenter.setSource(source), sourceLocation: sourceLocation)
        accept(shell, "shader.run", [1], sourceLocation: sourceLocation)
        try draw(session)
    }

    /// Whether `a` and `b` differ in any colour channel.
    static func differs(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        a.count != b.count || a != b
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func studioDigest(_ core: StudioCore) throws -> String {
    var builder = DigestBuilder(domain: StudioCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func studioApplied(_ core: StudioCore, _ control: String, _ values: [Double]) -> (StudioCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
