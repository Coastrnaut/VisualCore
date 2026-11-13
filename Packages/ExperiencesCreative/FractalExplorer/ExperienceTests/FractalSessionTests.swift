// FractalSessionTests — feature 193 (UA-F07) T-U07-024 (FR-U07-003, FR-U07-011; SC-U07-003, SC-U07-005). The A03
// adapter inside the one app's session host on the simulator: open with the first frame and its probe, close without
// GPU objects across both families and the palettes, suspension, a memory warning and a context recreation that keep
// the digest, repeated opens, and parity of the framing with the standalone app's `ExplorerModel` for three seeds and
// view sizes. Hosted by the VisualCore app.
import XCTest
import FractalExplorerCore
@testable import FractalExplorerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
final class FractalSessionTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.ua-f07.a03.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var id: ExperienceID { FractalExperience.id ?? ExperienceID(rawValue: "a03.unknown")! }

    private func request(seed: UInt64 = FractalCore.manifestSeed,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed) {
            let experience = FractalExperience.make(id: id, storage: storage, reduceMotion: false)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession) {
        guard let view = session.renderHost?.view else { return }
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
    }

    private func digest(_ experience: (any Experience)?) throws -> String {
        let shell = try XCTUnwrap(experience as? ExperienceShell<FractalPresenter>)
        return try shell.engine.digest().hex
    }

    func testOpeningDrawsTheFirstFrameAndItsProbeMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let opened = await session.open(request())
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let experience = try XCTUnwrap(session.experience)
        try experience.reset()
        XCTAssertEqual(try digest(experience), FractalCore.initialDigest)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let probes = experience.frameProbes
        XCTAssertEqual(probes.count, 1, "the default view's centre lies inside the set")
        let size = host.pixelSize
        let pixels = host.readPixels()
        for probe in probes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue,
                           probe.expected, probe.name)
        }
        XCTAssertTrue(experience.accessibilitySummary.hasPrefix("Mandelbrot set, centered at"),
                      experience.accessibilitySummary)
    }

    func testCloseLeavesNoGPUObjectAcrossFamiliesAndPalettes() async throws {
        let session = ExperienceSession()
        for mode in 0...1 {
            var made: (any Experience)?
            let opened = await session.open(request { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let experience = try XCTUnwrap(made)
            if mode == 1 { XCTAssertTrue(experience.handle(control: "mode", values: [1]).isAccepted) }
            for palette in 0..<FractalCore.paletteIDs.count {
                XCTAssertTrue(experience.handle(control: "palette", values: [Double(palette)]).isAccepted)
                XCTAssertTrue(experience.handle(control: "zoomIn", values: []).isAccepted)
                XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            }
            session.close()
            let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
            XCTAssertEqual(counts.objects, 0, "mode \(mode)")
            XCTAssertEqual(counts.leaked, 0, "mode \(mode)")
        }
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testSuspensionMemoryWarningAndContextRecreationKeepTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(experience.handle(control: "pan", values: [0.1, 0.1]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        session.setScenePhase(.background)
        let before = try digest(experience)
        XCTAssertEqual(session.state, .suspended)
        session.setScenePhase(.active)
        XCTAssertEqual(try digest(experience), before, "no steps for the time away")
        session.handleMemoryWarning()
        XCTAssertEqual(try digest(experience), before)
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
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

    func testTheFramingEqualsTheStandaloneModelsForThreeSeedsAndSizes() async throws {
        for (seed, size) in [(UInt64(3), Vec2(390, 844)), (41, Vec2(1024, 768)), (0xBEEF, Vec2(320, 320))] {
            let model = ExplorerModel(size: size, hosted: false)
            defer { model.close() }
            var engine = ExperienceEngine<FractalCore>(id: id)
            try await engine.prepare(seed: seed)
            try engine.activate()
            let side = min(size.x, size.y)
            model.zoomIn()
            model.apply(model.state.viewport.panned(by: Vec2(30, -12)))
            model.apply(model.state.viewport.pinched(by: 1.5, anchor: Vec2(size.x * 0.25, size.y * 0.7)))
            model.zoomOut()
            let anchor = (Vec2(size.x * 0.25, size.y * 0.7) - size / 2) / side
            for (control, values) in [("zoomIn", [Double]()), ("pan", [30 / side, -12 / side]),
                                      ("pinch", [1.5, anchor.x, anchor.y]), ("zoomOut", [])] {
                XCTAssertTrue(engine.handle(control: control, values: values).isAccepted, control)
            }
            let framing = try XCTUnwrap(engine.core).framing
            let expected = PlaneFraming(model.state.viewport)
            XCTAssertEqual(framing.center.x, expected.center.x, accuracy: 1e-12 * max(1, abs(expected.center.x)))
            XCTAssertEqual(framing.center.y, expected.center.y, accuracy: 1e-12 * max(1, abs(expected.center.y)))
            XCTAssertEqual(framing.span, expected.span, accuracy: 1e-12 * expected.span)
            XCTAssertEqual(try XCTUnwrap(engine.core).state(size: size).spokenDescription,
                           model.state.spokenDescription, "seed \(seed)")
        }
    }
}
