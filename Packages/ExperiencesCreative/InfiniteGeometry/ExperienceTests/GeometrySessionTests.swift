// GeometrySessionTests — feature 040 (A05-P01) T-A05-106 (FR-A05-121, FR-A05-132; SC-A05-102). The A05 adapter
// inside the one app's session host on the simulator, with short runs only: each of the four curated presets opened
// through `ExperienceSession` draws a non-blank frame with elements and its background probe matching, the spoken
// description names the kind and the symmetry, a context recreation keeps the digest and draws again, and closing
// leaves no GPU object. Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class GeometrySessionTests: XCTestCase {
    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(seed: UInt64 = GeometryCore.manifestSeed,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-session-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-session-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession) {
        guard let view = session.renderHost?.view else { return }
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
    }

    private func shell(_ experience: (any Experience)?) throws -> ExperienceShell<GeometryPresenter> {
        try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
    }

    func testEachCuratedPresetDrawsANonBlankFrameWhoseProbeMatches() async throws {
        let session = ExperienceSession()
        for (index, preset) in GeometryPreset.curated.enumerated() {
            var made: (any Experience)?
            let opened = await session.open(request { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let experience = try XCTUnwrap(made)
            if index > 0 {
                XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(index)]).isAccepted, "\(index)")
            }
            let host = try XCTUnwrap(session.renderHost)
            for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false), "preset \(index)") }
            XCTAssertGreaterThan(try shell(experience).presenter.drawnCount, 0, "preset \(index) draws elements")
            let size = host.pixelSize
            let pixels = host.readPixels()
            XCTAssertTrue(FrameChecks.isNonBlank(pixels, width: size.width, height: size.height), "preset \(index)")
            let probes = experience.frameProbes
            XCTAssertEqual(probes.count, 1, "preset \(index): one background probe")
            for probe in probes {
                XCTAssertEqual(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue,
                               probe.expected, "preset \(index) \(probe.name)")
            }
            let summary = experience.accessibilitySummary
            XCTAssertTrue(summary.hasPrefix("Infinite Geometry: \(GeometryCore.kindName(preset.kind)), "), summary)
            XCTAssertTrue(summary.contains(GeometryCore.symmetryText(try XCTUnwrap(shell(experience).engine.core).preset)),
                          summary)
            session.close()
            let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
            XCTAssertEqual(counts.objects, 0, "preset \(index)")
            XCTAssertEqual(counts.leaked, 0, "preset \(index)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testContextRecreationKeepsTheDigestAndCloseLeavesNoGPUObject() async throws {
        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        let solid = GeometryPreset.curated.firstIndex { $0.kind == .solid } ?? 3
        // A plane, then the solid (a mesh renderer is made), then another order (the mesh renderer is remade).
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(solid)]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        let order = try XCTUnwrap(shell(experience).engine.core).preset.order == 4 ? 5 : 4
        XCTAssertTrue(experience.handle(control: "symmetry.order", values: [Double(order)]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        let before = try shell(experience).engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell(experience).engine.digest(), before)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertGreaterThan(try shell(experience).presenter.drawnCount, 0)
        session.close()
        let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
        XCTAssertEqual(counts.objects, 0)
        XCTAssertEqual(counts.leaked, 0)
        XCTAssertEqual(session.hostsAlive, 0)
    }
}
