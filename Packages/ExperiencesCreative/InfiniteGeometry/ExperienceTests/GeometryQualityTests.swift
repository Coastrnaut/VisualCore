// GeometryQualityTests — feature 044 (A05-P05) T-A05-506 (FR-A05-501–506, FR-A05-510; SC-A05-501–503). Adaptive
// tessellation and the presenter's mesh cache, short runs only (owner rule of 2026-11-13):
//   - pure: the profile Full/High/Medium/Low gives 24/16/12/8 segments; for solid orders 3, 5, 8 and 12 the triangle
//     counts never rise over tiers 0–3, tier 3 has at most half of tier 0's, every tier mesh is closed, valid within
//     `MeshBudget.default` and inside the reference bounding sphere; tier 0 is the reference mesh;
//   - the tier is not state: for every preset kind the digest, the snapshot and a saved composition are identical at
//     every tier, `==` ignores the tier, a reset keeps it, a tier outside the profile is clamped;
//   - through the one app's session host on the simulator: a pinned level draws its tessellation; A → B → A at one
//     tier is one cache hit and two builds; a tier change switches the drawn mesh at the next frame, not before; a
//     context recreation draws again from the cached CPU mesh (a hit, no build). Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class GeometryQualityTests: XCTestCase {
    /// The solid orders of SC-A05-501.
    static let orders = [3, 5, 8, 12]

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    /// The curated preset index of `kind`.
    private static func index(_ kind: GeometryPreset.Kind) -> Int {
        GeometryPreset.curated.firstIndex { $0.kind == kind } ?? 0
    }

    /// The curated solid with symmetry order `order`.
    private static func solid(order: Int) -> GeometryPreset {
        var preset = GeometryPreset.curated[index(.solid)]
        preset.order = order
        return preset
    }

    // MARK: Pure

    func testTheProfileHasFourLevelsWithFallingSegments() {
        let profile = GeometryCore.qualityProfile
        XCTAssertEqual(profile.names, ["Full", "High", "Medium", "Low"])
        XCTAssertEqual(profile.count, GeometryCore.qualityTiers)
        XCTAssertEqual(QualityDeclaration.problems(profile: profile, tierCount: GeometryCore.qualityTiers,
                                                   catalogNames: nil), [])
        XCTAssertEqual(profile.levels.map(\.elementShare), [1, 2.0 / 3.0, 0.5, 1.0 / 3.0])
        XCTAssertTrue(profile.levels.allSatisfy {
            $0.resolutionShare == 1 && $0.iterationShare == 1 && $0.effectPasses == 0
        })
        XCTAssertEqual((0..<4).map(GeometryCore.segments(forTier:)), [24, 16, 12, 8])
        XCTAssertEqual(GeometryCore.segments(forTier: -1), 24, "a tier below the profile is the best")
        XCTAssertEqual(GeometryCore.segments(forTier: 9), 8, "a tier beyond the profile is the cheapest")
    }

    func testTriangleCountsFallOverTheTiersAndEveryMeshValidates() throws {
        for order in Self.orders {
            let preset = Self.solid(order: order)
            guard case .solid(let reference) = try Composition.build(preset) else {
                return XCTFail("order \(order): the solid preset builds a mesh")
            }
            let centre = try XCTUnwrap(reference.bounds.center), radius = try XCTUnwrap(reference.bounds.radius)
            var counts: [Int] = []
            var signatures: Set<UInt64> = []
            for tier in 0..<GeometryCore.qualityTiers {
                let segments = GeometryCore.segments(forTier: tier)
                let mesh = try Composition.solidMesh(preset, segments: segments)
                let report = mesh.validate(requireClosed: true, budget: .default)
                XCTAssertTrue(report.isValid, "order \(order) tier \(tier): \(report)")
                XCTAssertLessThanOrEqual(mesh.positions.count, MeshBudget.default.maxVertices)
                XCTAssertLessThanOrEqual(mesh.indices.count, MeshBudget.default.maxIndices)
                // Lower tiers lie on the same surfaces: inside the reference sphere (the Phase 03 camera rule).
                let farthest = mesh.positions.map { ($0 - centre).length }.max() ?? 0
                XCTAssertLessThanOrEqual(farthest, radius + 1e-9, "order \(order) tier \(tier)")
                counts.append(mesh.triangleCount)
                signatures.insert(Composition.meshSignature(preset, segments: segments))
                if tier == 0 {
                    XCTAssertEqual(mesh.digest, reference.digest, "order \(order): tier 0 is the reference")
                }
            }
            for tier in 1..<counts.count {
                XCTAssertLessThanOrEqual(counts[tier], counts[tier - 1], "order \(order): tier \(tier) never rises")
            }
            XCTAssertLessThanOrEqual(2 * counts[3], counts[0], "order \(order): tier 3 ≤ 50% of tier 0 (\(counts))")
            XCTAssertEqual(signatures.count, GeometryCore.qualityTiers, "order \(order): one signature per tier")
        }
        // The signature follows the shape, not the palette.
        let preset = Self.solid(order: 6)
        var recoloured = preset
        recoloured.palette = (preset.palette + 1) % 6
        XCTAssertEqual(Composition.meshSignature(recoloured, segments: 16),
                       Composition.meshSignature(preset, segments: 16))
        XCTAssertNotEqual(Composition.meshSignature(Self.solid(order: 5), segments: 16),
                          Composition.meshSignature(preset, segments: 16))
    }

    func testTheTierChangesNoDigestSnapshotOrSavedComposition() async throws {
        var engine = ExperienceEngine<GeometryCore>(id: id)
        try await engine.prepare(seed: GeometryCore.manifestSeed)
        try engine.activate()
        for kind in GeometryPreset.Kind.allCases {
            let index = Self.index(kind)
            try engine.setQualityTier(0)
            if try XCTUnwrap(engine.core).presetIndex != index {
                XCTAssertTrue(engine.handle(control: "preset.select", values: [Double(index)]).isAccepted, "\(kind)")
            }
            let digest = try engine.digest()
            let snapshot = try engine.snapshot()
            let core = try XCTUnwrap(engine.core)
            // Sorted keys, as the library writes them (an unsorted encoder may order nested keys differently per call).
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let document = try encoder.encode(GeometryDocument(core: core, name: "Tier"))
            for tier in 0..<GeometryCore.qualityTiers {
                try engine.setQualityTier(tier)
                let tiered = try XCTUnwrap(engine.core)
                XCTAssertEqual(tiered.qualityTier, tier, "\(kind) tier \(tier)")
                XCTAssertEqual(try engine.digest(), digest, "\(kind) tier \(tier): the digest")
                let again = try engine.snapshot()
                XCTAssertEqual(again.payload, snapshot.payload, "\(kind) tier \(tier): the snapshot payload")
                XCTAssertEqual(again.digest, snapshot.digest, "\(kind) tier \(tier): the snapshot digest")
                XCTAssertEqual(try tiered.snapshotPayload(), try core.snapshotPayload(), "\(kind) tier \(tier)")
                XCTAssertEqual(try encoder.encode(GeometryDocument(core: tiered, name: "Tier")), document,
                               "\(kind) tier \(tier): the saved composition")
                XCTAssertEqual(tiered, core, "\(kind) tier \(tier): the tier is not state")
            }
        }
        // Clamping and reset (the tier is kept, it is not state).
        var core = try XCTUnwrap(engine.core)
        core.setQualityTier(9)
        XCTAssertEqual(core.qualityTier, 3)
        XCTAssertEqual(core.drawSegments, 8)
        core.setQualityTier(-2)
        XCTAssertEqual(core.qualityTier, 0)
        core.setQualityTier(2)
        core.reset()
        XCTAssertEqual(core.qualityTier, 2)
        XCTAssertEqual(core.presetIndex, 0)
    }

    // MARK: Session

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-quality-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-quality-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    /// A running session pinned to `pin` on a 160 × 240 point view, with the solid preset selected (no frame drawn
    /// of it yet).
    private func openSolid(pin: Int) async throws
        -> (ExperienceSession, any Experience, ExperienceShell<GeometryPresenter>, RenderHost) {
        let session = ExperienceSession()
        session.qualityPin = pin
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
        let experience = try XCTUnwrap(made)
        let shell = try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
        XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(Self.index(.solid))]).isAccepted)
        return (session, experience, shell, try XCTUnwrap(session.renderHost))
    }

    /// The triangle count of the current solid's mesh at `tier`.
    private func triangles(_ shell: ExperienceShell<GeometryPresenter>, tier: Int) throws -> Int {
        let preset = try XCTUnwrap(shell.engine.core).preset
        return try Composition.solidMesh(preset, segments: GeometryCore.segments(forTier: tier)).triangleCount
    }

    func testAPinnedLevelDrawsItsTessellation() async throws {
        let (session, _, shell, host) = try await openSolid(pin: 3)
        defer { session.close() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.engine.qualityTier, 3)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).qualityTier, 3)
        XCTAssertEqual(shell.presenter.drawnSegments, 8)
        XCTAssertEqual(shell.presenter.drawnTriangleCount, try triangles(shell, tier: 3))
        XCTAssertLessThan(shell.presenter.drawnTriangleCount, try XCTUnwrap(shell.engine.core).elementCount,
                          "the reference composition (digest, description) stays at full tessellation")
    }

    func testReturningToAPresetIsOneCacheHit() async throws {
        let (session, experience, shell, host) = try await openSolid(pin: 1)
        defer { session.close() }
        let cache = shell.presenter.meshCache
        let order = try XCTUnwrap(shell.engine.core).preset.order
        let other = order == 5 ? 6 : 5
        // One frame per state: A, B, A.
        XCTAssertTrue(host.renderOneFrame(present: false), "A")
        let a = Composition.meshSignature(try XCTUnwrap(shell.engine.core).preset, segments: 16)
        XCTAssertTrue(experience.handle(control: "symmetry.order", values: [Double(other)]).isAccepted)
        XCTAssertTrue(host.renderOneFrame(present: false), "B")
        let b = Composition.meshSignature(try XCTUnwrap(shell.engine.core).preset, segments: 16)
        XCTAssertTrue(experience.handle(control: "symmetry.order", values: [Double(order)]).isAccepted)
        XCTAssertTrue(host.renderOneFrame(present: false), "A again")
        XCTAssertEqual(cache.misses, 2, "A and B are built once each")
        XCTAssertEqual(cache.hits, 1, "the return to A is taken from the cache")
        XCTAssertTrue(cache.contains(a))
        XCTAssertTrue(cache.contains(b))
        XCTAssertEqual(shell.presenter.drawnTriangleCount, try triangles(shell, tier: 1))
    }

    func testATierChangeSwitchesTheMeshAtTheNextFrame() async throws {
        let (session, _, shell, host) = try await openSolid(pin: 0)
        defer { session.close() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let full = try triangles(shell, tier: 0)
        XCTAssertEqual(shell.presenter.drawnTriangleCount, full)
        XCTAssertEqual(full, try XCTUnwrap(shell.engine.core).elementCount)
        let digest = try shell.engine.digest()
        session.qualityPin = 2
        XCTAssertEqual(shell.engine.qualityTier, 2)
        XCTAssertEqual(shell.presenter.drawnTriangleCount, full, "nothing changes until the next frame")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.presenter.drawnSegments, 12)
        XCTAssertEqual(shell.presenter.drawnTriangleCount, try triangles(shell, tier: 2))
        XCTAssertLessThan(shell.presenter.drawnTriangleCount, full)
        XCTAssertEqual(try shell.engine.digest(), digest, "the tier change keeps the digest")
        session.qualityPin = 0
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.presenter.drawnTriangleCount, full, "back at full tessellation")
    }

    func testAContextRecreationDrawsFromTheCachedMesh() async throws {
        let (session, _, shell, host) = try await openSolid(pin: 2)
        defer { session.close() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.presenter.drawnSegments, 12)
        let cache = shell.presenter.meshCache
        let misses = cache.misses, hits = cache.hits
        XCTAssertEqual(misses, 1)
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        let rebuilt = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(rebuilt.renderOneFrame(present: false))
        XCTAssertEqual(cache.misses, misses, "the CPU mesh is not built again")
        XCTAssertGreaterThan(cache.hits, hits, "the frame after the recreation is a cache hit")
        XCTAssertEqual(shell.presenter.drawnTriangleCount, try triangles(shell, tier: 2))
        let size = rebuilt.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(rebuilt.readPixels(), width: size.width, height: size.height))
    }
}
