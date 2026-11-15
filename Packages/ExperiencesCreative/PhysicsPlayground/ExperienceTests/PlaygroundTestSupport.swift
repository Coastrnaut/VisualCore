// PlaygroundTestSupport — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121). Shared helpers of the Physics
// Playground experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels
// of a frame, counting the pixels two frames differ in, and building a core that holds a given world. Feature 085
// (A11-P04) T-A11-403 adds a temporary experience storage for the saved-experiment tests. Feature 086 (A11-P05)
// T-A11-504: the opened experience is given Low Power Mode off unless a test injects it, so every drawing level is the
// host's tier.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
enum PlaygroundTest {
    /// The experience id `a11.physics-playground`.
    static var id: ExperienceID { PhysicsPlaygroundExperience.id ?? ExperienceID(rawValue: "a11.unknown")! }

    /// Opens Physics Playground in `session` (seed `seed`, optionally restoring `snapshot`, with the saved
    /// experiments of `store`, in memory when nil, and Low Power Mode from `lowPowerMode`, off when nil), lays the
    /// view out at `size` points and draws one frame.
    static func open(_ session: ExperienceSession, seed: UInt64 = 7, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 120, height: 100), store: ExperimentStore? = nil,
                     lowPowerMode: (@MainActor () -> Bool)? = nil) async throws
        -> ExperienceShell<PlaygroundPresenter> {
        let id = self.id
        var made: ExperienceShell<PlaygroundPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = PhysicsPlaygroundExperience.make(id: id, store: store, lowPowerMode: lowPowerMode ?? { false })
            made = shell
            return shell
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
    static func core(_ shell: ExperienceShell<PlaygroundPresenter>) throws -> PlaygroundCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back (each advances the host by 1/60 s: two host steps of 1/120 s).
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> (rgba: [UInt8], width: Int, height: Int) {
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

    /// The RGBA of the pixel at (`x`, `y`) of a frame (y from the top of the canvas; the read rows are bottom-up).
    static func pixel(_ frame: (rgba: [UInt8], width: Int, height: Int), x: Int, y: Int) -> [UInt8] {
        guard x >= 0, y >= 0, x < frame.width, y < frame.height else { return [] }
        let index = ((frame.height - 1 - y) * frame.width + x) * 4
        guard index + 3 < frame.rgba.count else { return [] }
        return Array(frame.rgba[index..<(index + 4)])
    }
}

/// A core holding `world` and the generator of `seed` (prepared with `seed`), through the restore path.
func playgroundCore(_ world: PhysicsWorld, seed: UInt64 = 7) throws -> PlaygroundCore {
    try PlaygroundCore.restore(payload: PlaygroundCore.encode(PlaygroundState(world: world,
                                                                             random: SeededRandom(seed: seed).state)),
                               seed: seed)
}

/// A world with the static ledge, a wood circle (radius 0.5 at (3, 5), angle 0.6) and a steel box (half-extents
/// 0.6 × 0.3 at (7, 3), angle 0.4).
func playgroundSampleWorld() -> PhysicsWorld {
    PhysicsWorld(bodies: [
        PhysicsBody(id: 0, shape: .box(halfExtents: StartingScene.ledgeHalfExtents), materialId: "steel",
                    isStatic: true, position: StartingScene.ledgeCenter),
        PhysicsBody(id: 1, shape: .circle(radius: 0.5), materialId: "wood", position: Vec2(3, 5), angle: 0.6),
        PhysicsBody(id: 2, shape: .box(halfExtents: Vec2(0.6, 0.3)), materialId: "steel", position: Vec2(7, 3),
                    angle: 0.4),
    ])
}

/// A temporary storage of Physics Playground (feature 085): its root folder and defaults suite are removed by
/// ``remove()``.
struct TemporaryPlaygroundStorage {
    let root: URL
    let suite: String
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "pp-experiments-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        let id = ExperienceID(rawValue: PlaygroundCore.experienceID) ?? ExperienceID(rawValue: "a11.unknown")!
        storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// The experience's folder (`<root>/a11.physics-playground/`).
    var folder: URL {
        root.appendingPathComponent(storage.id.storageNamespace, isDirectory: true)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}
