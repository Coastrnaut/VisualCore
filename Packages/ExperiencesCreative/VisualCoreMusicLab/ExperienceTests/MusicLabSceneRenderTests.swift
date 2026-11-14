// MusicLabSceneRenderTests — feature 049 (A06-P03) T-A06-309 (FR-A06-310, 311, 314, 315; SC-A06-303, 304). The three
// scenes inside the one app's session host on the simulator, short runs only (each test under 5 s): with the 1 kHz demo
// tone every scene draws a non-blank picture and the three pictures differ pairwise on a 16 × 16 sampling grid; each
// scene's picture differs between silence and the tone; a gain of 2 doubles the settled normalised value inside the
// range; Reduce Motion keeps the spin at its minimum; the scene survives a snapshot round trip; the description names
// the scene.
import XCTest
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering

/// A permission that is never asked (the demo needs none).
@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

@MainActor
final class MusicLabSceneRenderTests: XCTestCase {
    private var id: ExperienceID { VisualCoreMusicLabExperience.id ?? ExperienceID(rawValue: "a06.unknown")! }

    private func open(_ session: ExperienceSession, reduceMotion: Bool = false) async throws
        -> ExperienceShell<MusicLabPresenter> {
        let id = self.id
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: GrantedPermission(), factory: .system,
                                                          reduceMotion: reduceMotion)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    /// Lets the source write two analysis windows (bounded) and draws `frames` frames ~16 ms apart.
    private func settle(_ shell: ExperienceShell<MusicLabPresenter>, _ session: ExperienceSession,
                        frames: Int = 30) async throws {
        let start = shell.presenter.ring.totalWritten
        for _ in 0..<100 where shell.presenter.ring.totalWritten < start + 2 * MusicLabPresenter.analysisSize {
            try await Task.sleep(for: .milliseconds(10))
        }
        for _ in 0..<frames {
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            try await Task.sleep(for: .milliseconds(16))
        }
    }

    /// The RGB of a 16 × 16 grid of points over the view.
    private func grid(_ session: ExperienceSession) throws -> [[UInt8]] {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let pixels = host.readPixels()
        let size = host.pixelSize
        var out: [[UInt8]] = []
        for gy in 0..<16 {
            for gx in 0..<16 {
                let x = (gx * 2 + 1) * size.width / 32, y = (gy * 2 + 1) * size.height / 32
                let i = (y * size.width + x) * 4
                out.append([pixels[i], pixels[i + 1], pixels[i + 2]])
            }
        }
        return out
    }

    private func differingShare(_ a: [[UInt8]], _ b: [[UInt8]]) -> Double {
        let differing = zip(a, b).filter { p, q in zip(p, q).contains { abs(Int($0) - Int($1)) > 16 } }.count
        return Double(differing) / Double(a.count)
    }

    func testTheThreeScenesDrawDifferentPicturesOfTheTone() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        var pictures: [[[UInt8]]] = []
        for scene in MusicLabScene.allCases {
            XCTAssertTrue(shell.handle(control: "scene.select", values: [Double(scene.rawValue)]).isAccepted)
            try await settle(shell, session)
            XCTAssertEqual(shell.presenter.lastScene, scene)
            let picture = try grid(session)
            let background = picture[0]
            XCTAssertTrue(picture.contains { $0 != background }, "\(scene) is not blank")
            pictures.append(picture)
            XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Music Lab: \(scene.displayName) scene, Demo signal"),
                          shell.accessibilitySummary)
        }
        for i in 0..<3 {
            for j in (i + 1)..<3 {
                XCTAssertGreaterThanOrEqual(differingShare(pictures[i], pictures[j]), 0.10, "scenes \(i) and \(j)")
            }
        }
        session.close()
    }

    func testEachSceneChangesBetweenSilenceAndTheTone() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        for scene in MusicLabScene.allCases {
            XCTAssertTrue(shell.handle(control: "scene.select", values: [Double(scene.rawValue)]).isAccepted)
            XCTAssertTrue(shell.handle(control: "demo.mode", values: [3]).isAccepted)
            try await settle(shell, session)
            let quiet = try grid(session)
            let rest = shell.presenter.lastParameterValues
            XCTAssertTrue(zip(rest, scene.parameters).allSatisfy { abs($0 - $1.range.lowerBound) < 1e-6 },
                          "\(scene) rests at its minimums: \(rest)")
            XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
            try await settle(shell, session)
            let loud = try grid(session)
            XCTAssertGreaterThan(differingShare(quiet, loud), 0, "\(scene)")
        }
        session.close()
    }

    func testAGainOfTwoDoublesTheSettledValueInsideTheRange() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "scene.select", values: [2]).isAccepted)
        // Pulse follows the level (index 0) with gain 1, then 2.
        XCTAssertTrue(shell.handle(control: "mapping.set", values: [2, 0, 0, 1]).isAccepted)
        try await settle(shell, session, frames: 40)
        let pulse = MusicLabScene.geometry.parameters[0].range
        let one = (shell.presenter.lastParameterValues[0] - pulse.lowerBound) / (pulse.upperBound - pulse.lowerBound)
        XCTAssertTrue(shell.handle(control: "mapping.set", values: [2, 0, 0, 2]).isAccepted)
        try await settle(shell, session, frames: 40)
        let value = shell.presenter.lastParameterValues[0]
        XCTAssertTrue(pulse.contains(value))
        // Convergence T-A06-320 (US2, FR-A06-312): the editor's live values are the frame's values in hundredths.
        XCTAssertEqual(shell.presenter.mirror.parameterValues,
                       shell.presenter.lastParameterValues.map { ($0 * 100).rounded() / 100 })
        let two = (value - pulse.lowerBound) / (pulse.upperBound - pulse.lowerBound)
        XCTAssertEqual(two, min(1, 2 * one), accuracy: 0.05)
        session.close()
    }

    func testReduceMotionKeepsTheSpinAtItsMinimum() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, reduceMotion: true)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "scene.select", values: [2]).isAccepted)
        // The pulse follows the beat by default (none in a steady tone); let it follow the level here.
        XCTAssertTrue(shell.handle(control: "mapping.set", values: [2, 0, 0, 1]).isAccepted)
        try await settle(shell, session)
        let spin = MusicLabScene.geometry.parameters[1].range
        XCTAssertEqual(shell.presenter.lastParameterValues[1], spin.lowerBound, accuracy: 1e-9)
        XCTAssertGreaterThan(shell.presenter.lastParameterValues[0], MusicLabScene.geometry.parameters[0].range.lowerBound,
                             "the pulse still follows the sound")
        session.close()
    }

    func testTheSceneAndMappingSurviveASnapshot() async throws {
        let first = ExperienceSession()
        let shell = try await open(first)
        XCTAssertTrue(shell.handle(control: "scene.select", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "mapping.set", values: [1, 1, 6, 3]).isAccepted)
        var copy = shell.engine
        let snapshot = try copy.snapshot()
        first.close()
        var engine = ExperienceEngine<MusicLabCore>(id: id)
        try await engine.prepare(seed: 1)
        try engine.activate()
        try engine.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.scene, .rings)
        XCTAssertEqual(state.mappings[1][1], MappingChoice(feature: 6, gain: 3))
    }
}
