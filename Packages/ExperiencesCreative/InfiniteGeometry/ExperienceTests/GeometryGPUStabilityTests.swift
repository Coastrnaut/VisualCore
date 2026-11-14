// GeometryGPUStabilityTests — feature 043 (A05-P04) T-A05-406 (FR-A05-420, SC-A05-404). No GPU object accumulates
// over preset transitions or saved-composition opens, through the one app's session host on the simulator, short
// runs only: the curated presets are cycled three times with a frame after every change, and the render host's
// resource ledger live counts after cycles 2 and 3 equal those after cycle 1 with nothing leaked; then a saved
// composition of every kind is opened in turn twice (one atomic `composition.open` each, a frame after each) with
// the same equality, and each open restores the digest at save time. Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class GeometryGPUStabilityTests: XCTestCase {
    /// The preset cycles.
    static let cycles = 3

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-stability-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-stability-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func shell(_ experience: (any Experience)?) throws -> ExperienceShell<GeometryPresenter> {
        try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
    }

    private func openSession() async throws -> (ExperienceSession, any Experience, RenderHost) {
        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
        return (session, try XCTUnwrap(made), try XCTUnwrap(session.renderHost))
    }

    func testPresetCyclesKeepTheLiveCountsAndLeakNothing() async throws {
        let (session, experience, host) = try await openSession()
        defer { session.close() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        var counts: [[String: Int]] = []
        for cycle in 1...Self.cycles {
            for index in GeometryPreset.curated.indices {
                if try XCTUnwrap(shell(experience).engine.core).presetIndex != index {
                    XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(index)]).isAccepted,
                                  "cycle \(cycle) preset \(index)")
                }
                XCTAssertTrue(host.renderOneFrame(present: false), "cycle \(cycle) preset \(index)")
            }
            let stats = host.resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            XCTAssertEqual(stats.shaderFailures, 0, "cycle \(cycle)")
            counts.append(Dictionary(uniqueKeysWithValues: stats.liveCount.map { ("\($0.key)", $0.value) }))
        }
        XCTAssertGreaterThan(counts[0].values.reduce(0, +), 0, "the presets hold GPU objects while drawn")
        for cycle in 1..<counts.count {
            XCTAssertEqual(counts[cycle], counts[0], "live counts after cycle \(cycle + 1) equal cycle 1")
        }
    }

    func testOpeningSavedCompositionsTwiceKeepsTheLiveCountsAndLeaksNothing() async throws {
        let (session, experience, host) = try await openSession()
        defer { session.close() }
        // One document per kind, each with a moved camera so the camera part of the open is exercised.
        var documents: [(document: GeometryDocument, digest: StateDigest)] = []
        for (index, preset) in GeometryPreset.curated.enumerated() {
            if try XCTUnwrap(shell(experience).engine.core).presetIndex != index {
                XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(index)]).isAccepted, "\(index)")
            }
            XCTAssertTrue(experience.handle(control: "camera.zoom", values: [1.25]).isAccepted, "\(index)")
            XCTAssertTrue(host.renderOneFrame(present: false), "\(index)")
            let core = try XCTUnwrap(shell(experience).engine.core)
            documents.append((GeometryDocument(core: core, name: GeometryCore.kindName(preset.kind)),
                              try shell(experience).engine.digest()))
        }
        XCTAssertTrue(experience.handle(control: "camera.reset", values: []).isAccepted)
        var counts: [[String: Int]] = []
        for round in 1...2 {
            for (index, saved) in documents.enumerated() {
                XCTAssertTrue(experience.handle(control: "composition.open", values: saved.document.openValues).isAccepted,
                              "round \(round) document \(index)")
                XCTAssertTrue(host.renderOneFrame(present: false), "round \(round) document \(index)")
                XCTAssertEqual(try shell(experience).engine.digest(), saved.digest,
                               "round \(round) document \(index): the open restores the digest at save time")
            }
            let stats = host.resources.stats
            XCTAssertEqual(stats.leaked, 0, "round \(round)")
            counts.append(Dictionary(uniqueKeysWithValues: stats.liveCount.map { ("\($0.key)", $0.value) }))
        }
        XCTAssertEqual(counts[1], counts[0], "live counts after the second round equal the first")
        XCTAssertEqual(session.state, .running)
    }
}
