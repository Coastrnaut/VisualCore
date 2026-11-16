// AnatomyTestSupport — feature 125 (A17-P02) T-A17-205 (FR-A17-202–208, FR-A17-210; SC-A17-202, SC-A17-205).
// Shared helpers of the Interactive Anatomy experience tests: opening the experience in the one app's session host
// with a real view size (a view without a frame size does not draw) and a throwaway storage; drawing frames; reading
// the pixels of a frame (rows bottom-up, as the host reads them back); counting the pixels two frames differ in and the
// pixels that are not the backdrop; projecting a region point through the camera of the last drawn frame; the engine
// digest of a core; the canvas description expected for a set of shown layers and a selection; snapshot envelopes and
// edited payloads.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias AnatomyFrame = (rgba: [UInt8], width: Int, height: Int)

/// Opening, drawing and reading Interactive Anatomy in the session host.
@MainActor
enum AnatomyTest {
    /// The experience id `a17.interactive-anatomy`.
    static var id: ExperienceID {
        InteractiveAnatomyExperience.id ?? ExperienceID(rawValue: "a17.unknown")!
    }

    /// The backdrop colour (0.07, 0.08, 0.10) in bytes.
    static let backdrop: (r: Int, g: Int, b: Int) = (18, 20, 26)

    /// A storage under a fresh temporary directory, so no test reads another's files.
    static func storage() -> ExperienceStorage {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ia-tests-\(UUID().uuidString)", isDirectory: true)
        return ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ia-experience-tests")!)
    }

    /// Opens Interactive Anatomy in `session` (seed `seed`, optionally restoring `snapshot`) through the factory, lays
    /// the view out at `size` points and draws one frame. A session without a quality pin is pinned to level 0, so the
    /// automatic level never changes a frame between two readings.
    static func open(_ session: ExperienceSession, seed: UInt64 = 1, snapshot: ExperienceSnapshot? = nil,
                     size: CGSize = CGSize(width: 240, height: 160)) async throws
        -> ExperienceShell<AnatomyPresenter> {
        let id = self.id
        let storage = storage()
        var made: ExperienceShell<AnatomyPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: false) {
            let shell = InteractiveAnatomyExperience.make(id: id, storage: storage, reduceMotion: false)
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

    /// Lays the view of `session` out at `size` points.
    static func resize(_ session: ExperienceSession, to size: CGSize) throws {
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<AnatomyPresenter>) throws -> AnatomyCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Sends `control` with `values` through the presenter and asserts it was accepted.
    static func accept(_ shell: ExperienceShell<AnatomyPresenter>, _ control: String, _ values: [Double] = [],
                       file: StaticString = #filePath, line: UInt = #line) {
        let result = shell.presenter.send(control, values, through: shell.port)
        XCTAssertTrue(result.isAccepted, "\(control) \(values): \(result.code)", file: file, line: line)
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count {
            let drawn = host.renderOneFrame(present: false)
            XCTAssertTrue(drawn)
        }
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> AnatomyFrame {
        let host = try XCTUnwrap(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        XCTAssertTrue(drawn)
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

    /// The number of pixels of `frame` more than 16 away from the backdrop in some channel.
    static func nonBackdropPixels(_ frame: AnatomyFrame) -> Int {
        var count = 0
        var i = 0
        let rgba = frame.rgba
        while i + 3 < rgba.count {
            if abs(Int(rgba[i]) - backdrop.r) > 16 || abs(Int(rgba[i + 1]) - backdrop.g) > 16
                || abs(Int(rgba[i + 2]) - backdrop.b) > 16 { count += 1 }
            i += 4
        }
        return count
    }

    /// The normalised device point (x, y in −1…1, y up) where `point` (region space) lies in the last drawn frame,
    /// through the presenter's last camera and aspect.
    static func projectedNDC(of point: Vec3, presenter: AnatomyPresenter) throws -> Vec2 {
        let camera = try XCTUnwrap(presenter.lastCamera, "a frame was drawn")
        let p = camera.project(point, aspect: presenter.lastAspect)
        return Vec2(p.x, p.y)
    }

    /// The part the picker finds under `ndc` in the last drawn frame of `shell`, with the core's scene and layers.
    static func expectedPick(_ shell: ExperienceShell<AnatomyPresenter>, at ndc: Vec2) throws -> Int? {
        let camera = try XCTUnwrap(shell.presenter.lastCamera, "a frame was drawn")
        let core = try self.core(shell)
        return AnatomyPicker.pick(ndc: ndc, camera: camera, aspect: shell.presenter.lastAspect, scene: core.scene,
                                  visible: core.visibleLayers)?.index
    }

    /// The mesh ids of the items of `scene` on `layer`.
    static func meshIDs(of layer: AnatomyLayer, in scene: AnatomyScene) -> Set<String> {
        Set(scene.items.filter { $0.layer == layer }.map(\.meshID))
    }
}

/// The layers in words, in `AnatomyLayer.allCases` order.
let anatomyLayerWords: [AnatomyLayer: String] = [
    .bones: "bones", .cartilage: "cartilage and menisci", .ligaments: "ligaments and tendons",
]

/// The canvas description expected for `shown` layers and the selected part's English name `selected`.
func anatomyDescription(shown: Set<AnatomyLayer>, selected: String?) -> String {
    let words = AnatomyLayer.allCases.filter { shown.contains($0) }.compactMap { anatomyLayerWords[$0] }
    let layers = words.isEmpty ? "no layer shown" : words.joined(separator: ", ")
    return "Right knee, \(layers); selected: \(selected ?? "nothing selected")."
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func anatomyDigest(_ core: AnatomyCore) throws -> String {
    var builder = DigestBuilder(domain: AnatomyCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func anatomyApplied(_ core: AnatomyCore, _ control: String, _ values: [Double] = []) -> (AnatomyCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}

/// A snapshot envelope of Interactive Anatomy around `payload` with the fields of `saved` and schema `schema`.
func anatomyEnvelope(_ payload: Data, like saved: ExperienceSnapshot, schema: Int = AnatomyViewState.schemaVersion)
    throws -> ExperienceSnapshot {
    let id = try XCTUnwrap(ExperienceID(rawValue: AnatomyCore.experienceID))
    return try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: saved.seed,
                                  stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
}

/// `payload` (a state's JSON) with `key` set to `value` (nil removes it) in its top-level object, as JSON with sorted
/// keys.
func anatomyPayload(_ payload: String, key: String, value: Any?) throws -> Data {
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    object[key] = value
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
