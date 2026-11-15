// WorldsTestSupport — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121). Shared helpers of the Tiny Worlds
// experience tests: opening the experience in the one app's session host, drawing frames, reading the pixels of a
// frame, counting the pixels two frames differ in, and building a core that holds a given world state. Feature 090
// (A12-P02) T-A12-205: the experience can be opened with Reduce Motion, a fixed system setting and a recording
// announcement sink with VoiceOver reported running, and frames can be drawn until the drawn view settles. Feature 091
// (A12-P03) T-A12-303: the experience can be opened with a `WorldStore` over a temporary storage
// (`TemporaryWorldsStorage`), the session's still renderer is offered as the host view offers it, and a world point is
// projected to view points through the drawn camera.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

@MainActor
enum WorldsTest {
    /// The experience id `a12.tiny-worlds`.
    static var id: ExperienceID { TinyWorldsExperience.id ?? ExperienceID(rawValue: "a12.unknown")! }

    /// Opens Tiny Worlds in `session` (seed `seed`, optionally restoring `snapshot`), lays the view out at `size`
    /// points and draws one frame. The system's Reduce Motion is reported off; `announcements`, when given, records
    /// what is spoken with VoiceOver reported running (otherwise VoiceOver is reported off). Low Power Mode is reported
    /// off unless `lowPowerMode` answers otherwise (feature 093).
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 120, height: 100), reduceMotion: Bool = false,
                     announcements: RecordingAnnouncementSink? = nil, store: WorldStore? = nil,
                     lowPowerMode: (@MainActor () -> Bool)? = nil) async throws
        -> ExperienceShell<WorldsPresenter> {
        let id = self.id
        var made: ExperienceShell<WorldsPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let voiceOver = announcements != nil
            let shell = TinyWorldsExperience.make(id: id, reduceMotion: reduceMotion, systemReduceMotion: { false },
                                                  voiceOverRunning: { voiceOver },
                                                  announcementSink: announcements ?? RecordingAnnouncementSink(),
                                                  store: store, lowPowerMode: lowPowerMode ?? { false })
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
    static func core(_ shell: ExperienceShell<WorldsPresenter>) throws -> WorldsCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// Draws frames (1/60 s each) until the drawn view has reached the state's view, at most 30 (0.5 s).
    static func settle(_ session: ExperienceSession, _ shell: ExperienceShell<WorldsPresenter>) throws {
        for _ in 0..<30 {
            try frames(session, 1)
            if shell.presenter.lastDrawnView == shell.engine.core?.view { return }
        }
        XCTFail("the drawn view did not settle within 0.5 s")
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> (rgba: [UInt8], width: Int, height: Int) {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The still renderer the host view hands to the controls, over `session` (feature 091).
    static func stillRenderer(_ session: ExperienceSession) -> ExperienceStillRenderer {
        ExperienceStillRenderer { [session] (width: Int, height: Int) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height)
        }
    }

    /// The view point (points, top-left origin) of the world point `p` seen through the camera of `view` on a canvas
    /// of `size` points; nil behind the eye.
    static func viewPoint(_ p: Vec3, view: WorldView, size: Vec2) -> Vec2? {
        let clip = WorldsPresenter.camera(view).viewProjection(aspect: size.x / size.y) * Vec4(p, 1)
        guard clip.w > 1e-9 else { return nil }
        return Vec2((clip.x / clip.w + 1) / 2 * size.x, (1 - clip.y / clip.w) / 2 * size.y)
    }

    /// The pixels of `frame` (rows read bottom-up) in the square of half-size `radius` around the view fraction
    /// (`fx`, `fy`) from the top left, as RGBA quadruples.
    static func region(_ frame: (rgba: [UInt8], width: Int, height: Int), fx: Double, fy: Double,
                       radius: Int) -> [[UInt8]] {
        let cx = Int(fx * Double(frame.width)), cy = Int(fy * Double(frame.height))
        var pixels: [[UInt8]] = []
        for y in (cy - radius)...(cy + radius) where y >= 0 && y < frame.height {
            for x in (cx - radius)...(cx + radius) where x >= 0 && x < frame.width {
                let index = ((frame.height - 1 - y) * frame.width + x) * 4
                pixels.append(Array(frame.rgba[index..<(index + 4)]))
            }
        }
        return pixels
    }

    /// The mean luma (0…255) of RGBA pixels.
    static func meanLuma(_ pixels: [[UInt8]]) -> Double {
        guard !pixels.isEmpty else { return 0 }
        let sum = pixels.reduce(0.0) { total, p in
            total + 0.2126 * Double(p[0]) + 0.7152 * Double(p[1]) + 0.0722 * Double(p[2])
        }
        return sum / Double(pixels.count)
    }

    /// The mean luma (0…255) of a whole frame.
    static func meanLuma(_ frame: (rgba: [UInt8], width: Int, height: Int)) -> Double {
        var sum = 0.0
        var i = 0
        while i + 3 < frame.rgba.count {
            sum += 0.2126 * Double(frame.rgba[i]) + 0.7152 * Double(frame.rgba[i + 1])
                + 0.0722 * Double(frame.rgba[i + 2])
            i += 4
        }
        return sum / Double(max(1, frame.rgba.count / 4))
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
func worldsDigest(_ core: WorldsCore) throws -> String {
    var builder = DigestBuilder(domain: WorldsCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A core holding `state`, prepared with `seed`, through the restore path.
func worldsCore(_ state: WorldState, seed: UInt64 = 1) throws -> WorldsCore {
    try WorldsCore.restore(payload: state.encoded(), seed: seed)
}

/// A snapshot envelope of Tiny Worlds around `payload` with the fields of `saved` and schema `schema`.
func worldsEnvelope(_ payload: Data, like saved: ExperienceSnapshot, schema: Int = 1) throws -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: WorldsCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                           stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a world state's JSON) with `change` applied to its top-level object, as JSON with sorted keys.
func worldsPayload(_ payload: String, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

/// A temporary storage of Tiny Worlds (feature 091): its root folder and defaults suite are removed by ``remove()``.
struct TemporaryWorldsStorage {
    let root: URL
    let suite: String
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "tw-worlds-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        let id = ExperienceID(rawValue: WorldsCore.experienceID) ?? ExperienceID(rawValue: "a12.unknown")!
        storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// The experience's folder (`<root>/a12.tiny-worlds/`).
    var folder: URL {
        root.appendingPathComponent(storage.id.storageNamespace, isDirectory: true)
    }

    /// Removes the folder (made writable first) and the defaults suite.
    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

/// A world state of `preset` and seed 1 with `count` props placed by the editor at spaced valid spots (kinds in turn),
/// the last one selected, and `light`.
func worldsStateWithProps(preset: Int = 0, count: Int, light: WorldLight = .default) -> WorldState {
    var state = WorldState(presetIndex: preset, seed: 1, view: .default, random: WorldState.initial.random,
                           light: light)
    let field = WorldEditing.groundField(of: state)
    var placed = 0
    var z = -5.0 + 0.123456789
    while z < 5.5, placed < count {
        var x = -5.0 + 0.0987654321
        while x < 5.5, placed < count {
            if WorldEditing.place(kind: placed % 4, x: x, z: z, in: &state, field: field) == nil { placed += 1 }
            x += 0.7
        }
        z += 0.7
    }
    return state
}

extension Result {
    /// The failure, nil for a success.
    var failure: Failure? {
        if case .failure(let failure) = self { return failure }
        return nil
    }
}
