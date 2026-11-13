// GenerativeArtSessionTests — feature 193 (UA-F07) T-U07-011 (FR-U07-011; SC-U07-003). The A01 adapter inside the
// one app's session host on the simulator: open, the first frame and its probe, close without GPU objects, suspension
// and return, retry after a refused restore, a memory warning, a context recreation and repeated opens across the
// four families. Hosted by the VisualCore app.
import XCTest
import GenerativeArtStudioCore
@testable import GenerativeArtStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class GenerativeArtSessionTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.ua-f07.a01.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var id: ExperienceID { GenerativeArtExperience.id ?? ExperienceID(rawValue: "a01.unknown")! }

    /// A request for A01 with `seed`; `made` receives every experience the factory builds.
    private func request(seed: UInt64 = GenerativeArtCore.manifestSeed, snapshot: ExperienceSnapshot? = nil,
                         refused: Bool = false,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: refused) {
            let experience = GenerativeArtExperience.make(id: id, storage: storage, reduceMotion: false,
                                                          reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession, width: CGFloat = 120, height: CGFloat = 200) {
        guard let view = session.renderHost?.view else { return }
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        view.layoutIfNeeded()
    }

    private func digest(_ experience: (any Experience)?) throws -> String {
        let shell = try XCTUnwrap(experience as? ExperienceShell<GenerativeArtPresenter>)
        return try shell.engine.digest().hex
    }

    // MARK: Tests

    func testOpeningDrawsTheFirstFrameAndItsProbeMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        // The open drew one frame, which ran steps; a reset returns to the committed state of a preparation.
        let experience = try XCTUnwrap(session.experience)
        try experience.reset()
        XCTAssertEqual(try digest(experience), GenerativeArtCore.initialDigest)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let probes = experience.frameProbes
        XCTAssertEqual(probes.count, 1, "the Particles background corner")
        let pixels = host.readPixels()
        let size = host.pixelSize
        for probe in probes {
            let found = FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)
            XCTAssertEqual(found?.rawValue, probe.expected, probe.name)
        }
        XCTAssertFalse(experience.accessibilitySummary.isEmpty)
    }

    func testCloseLeavesNoGPUObjectAcrossTheFourFamilies() async throws {
        let session = ExperienceSession()
        for family in 0..<FamilyCatalog.all.count {
            var made: (any Experience)?
            let opened = await session.open(request { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let experience = try XCTUnwrap(made)
            XCTAssertTrue(experience.handle(control: "family", values: [Double(family)]).isAccepted)
            for palette in 0..<FamilyCatalog.palettes.count {
                XCTAssertTrue(experience.handle(control: "palette", values: [Double(palette)]).isAccepted)
                XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            }
            session.close()
            let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
            XCTAssertEqual(counts.objects, 0, "family \(family): live objects after the close")
            XCTAssertEqual(counts.leaked, 0, "family \(family)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testSuspensionKeepsTheDigestAndTheReturnResumes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running)
        layOut(session)
        let before = try digest(session.experience)
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(try digest(session.experience), before)
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try digest(session.experience), before, "no steps for the time away")
    }

    func testRetryAfterARefusedRestoreOpensAgain() async throws {
        let other = try ExperienceSnapshot(experience: try XCTUnwrap(ExperienceID(rawValue: "a02.fluid-art-playground")),
                                           schemaVersion: 1, seed: 7, stepIndex: 0,
                                           digest: try XCTUnwrap(StateDigest(hex: GenerativeArtCore.initialDigest)),
                                           payload: Data("{}".utf8))
        let session = ExperienceSession()
        defer { session.close() }
        let failed = await session.open(request(snapshot: other, refused: true))
        guard case .failed = failed else { return XCTFail("a snapshot of another experience must be refused: \(failed)") }
        XCTAssertNil(session.renderHost, "no host after a refused restore")
        let again = await session.retry()
        guard case .failed = again else { return XCTFail("the same request fails again: \(again)") }
        XCTAssertEqual(session.diagnostics.failures, 2, "retry opened the last request again and it failed again")
        session.back()
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running, "a fresh open works after the failures")
    }

    func testAMemoryWarningShedsCachesAndKeepsTheState() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running)
        layOut(session)
        let before = try digest(session.experience)
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try digest(session.experience), before)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
    }

    func testAContextRecreationRedrawsTheSameState() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(experience.handle(control: "family", values: [1]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        let before = try digest(experience)
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.diagnostics.contextRecreations, 1)
        XCTAssertEqual(try digest(experience), before)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testTwentyOpensAndClosesLeaveNothingBehind() async throws {
        let session = ExperienceSession()
        for cycle in 0..<20 {
            let opened = await session.open(request(seed: UInt64(cycle)))
            XCTAssertEqual(opened, .running)
            layOut(session)
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }
}
