// SimulationTestSupport — feature 117 (A16-P01) T-A16-105 (FR-A16-130; SC-A16-105). Shared helpers of the Simulation
// Lab experience tests: opening the experience in the one app's session host with a real view size (a view without a
// frame size does not draw), with or without Reduce Motion; pausing it so frames stop advancing the simulation;
// drawing frames; reading the pixels of a frame (rows bottom-up, as the host reads them back); counting the pixels two
// frames differ in; and the engine digest of a core.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias SimulationFrame = (rgba: [UInt8], width: Int, height: Int)

/// Opening, drawing and reading Simulation Lab in the session host.
@MainActor
enum SimulationTest {
    /// The experience id `a16.simulation-lab`.
    static var id: ExperienceID {
        SimulationLabExperience.id ?? ExperienceID(rawValue: "a16.unknown")!
    }

    /// Opens Simulation Lab in `session` (seed `seed`, optionally restoring `snapshot`, with Reduce Motion
    /// `reduceMotion`) through the factory's wrapper, lays the view out at `size` points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 240, height: 160), reduceMotion: Bool = false) async throws
        -> ExperienceShell<SimulationPresenter> {
        let id = self.id
        var made: ExperienceShell<SimulationPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let experience = SimulationExperience(shell: SimulationLabExperience.make(id: id),
                                                  reduceMotion: reduceMotion)
            made = experience.shell
            return experience
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        try frames(session, 1)
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<SimulationPresenter>) throws -> SimulationCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Pauses `shell`'s simulation when it runs, so drawn frames no longer advance it.
    static func pause(_ shell: ExperienceShell<SimulationPresenter>) throws {
        if try core(shell).isRunning {
            XCTAssertTrue(shell.handle(control: "sim.pause").isAccepted)
        }
        XCTAssertFalse(try core(shell).isRunning)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> SimulationFrame {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The number of pixels whose RGB differs by more than 16 in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if abs(Int(a[i]) - Int(b[i])) > 16 || abs(Int(a[i + 1]) - Int(b[i + 1])) > 16
                || abs(Int(a[i + 2]) - Int(b[i + 2])) > 16 { count += 1 }
            i += 4
        }
        return count
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func simulationDigest(_ core: SimulationCore) throws -> String {
    var builder = DigestBuilder(domain: SimulationCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `action` with `values` applied directly (asserting nothing).
func simulationApplied(_ core: SimulationCore, _ control: String, _ values: [Double] = []) -> (SimulationCore,
                                                                                               ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
