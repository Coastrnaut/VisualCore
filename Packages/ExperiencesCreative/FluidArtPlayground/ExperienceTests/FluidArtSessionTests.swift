// FluidArtSessionTests — feature 193 (UA-F07) T-U07-021 (FR-U07-003, FR-U07-011; SC-U07-003, SC-U07-005; ADR-0011).
// The A02 adapter inside the one app's session host on the simulator: open with the first frame and its probe, close
// without GPU objects across the three detail levels and palettes, suspension, a memory warning, a context
// recreation that restarts the fields from the seeded pattern with the same digest, repeated opens, a splat that
// changes the picture, and parity of the configuration with the standalone app's `PlaygroundModel` for three seeds.
// Hosted by the VisualCore app.
import XCTest
import FluidArtPlaygroundCore
@testable import FluidArtPlaygroundExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class FluidArtSessionTests: XCTestCase {
    private var id: ExperienceID { FluidArtExperience.id ?? ExperienceID(rawValue: "a02.unknown")! }

    private func request(seed: UInt64 = FluidArtCore.manifestSeed,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed) {
            let experience = FluidArtExperience.make(id: id, reduceFlashing: false)
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
        let shell = try XCTUnwrap(experience as? ExperienceShell<FluidArtPresenter>)
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
        XCTAssertEqual(try digest(experience), FluidArtCore.initialDigest)
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let probes = experience.frameProbes
        XCTAssertEqual(probes.count, 1, "the emptiest region of the seeded pattern")
        let size = host.pixelSize
        let pixels = host.readPixels()
        for probe in probes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue,
                           probe.expected, probe.name)
        }
        XCTAssertFalse(experience.accessibilitySummary.isEmpty)
    }

    func testASplatChangesThePictureAndEndsTheProbe() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let before = host.readPixels()
        for _ in 0..<4 { XCTAssertTrue(experience.handle(control: "splash", values: []).isAccepted) }
        for _ in 0..<6 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let after = host.readPixels()
        let changed = zip(before, after).filter { abs(Int($0) - Int($1)) > 8 }.count
        XCTAssertGreaterThan(changed, before.count / 100, "the splashes reached the fields")
        XCTAssertTrue(experience.frameProbes.isEmpty, "a touched canvas declares no probe")
        XCTAssertEqual(experience.diagnostics.outcome?.code, "canvas-painted")
    }

    func testCloseLeavesNoGPUObjectAcrossDetailsAndPalettes() async throws {
        let session = ExperienceSession()
        for detail in 0..<FluidDetail.allCases.count {
            var made: (any Experience)?
            let opened = await session.open(request { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let experience = try XCTUnwrap(made)
            if detail != 1 { XCTAssertTrue(experience.handle(control: "detail", values: [Double(detail)]).isAccepted) }
            for palette in 0..<FluidPalette.all.count {
                XCTAssertTrue(experience.handle(control: "palette", values: [Double(palette)]).isAccepted)
                XCTAssertTrue(experience.handle(control: "splash", values: []).isAccepted)
                XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            }
            session.close()
            let counts = try XCTUnwrap(session.diagnostics.lastCloseCounts)
            XCTAssertEqual(counts.objects, 0, "detail \(detail)")
            XCTAssertEqual(counts.leaked, 0, "detail \(detail)")
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
        XCTAssertTrue(experience.handle(control: "splash", values: []).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        let before = try digest(experience)
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(try digest(experience), before)
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try digest(experience), before, "no steps for the time away")
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try digest(experience), before)
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.diagnostics.contextRecreations, 1)
        XCTAssertEqual(try digest(experience), before, "the picture restarts; the state does not (ADR-0011)")
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

    func testTheConfigurationEqualsTheStandaloneModelsForThreeSeeds() async throws {
        for seed: UInt64 in [3, 41, 0xBEEF_0000_1234_5678] {
            var start = FluidConfiguration()
            start.seed = seed
            let model = PlaygroundModel(configuration: start, hosted: false)
            var engine = ExperienceEngine<FluidArtCore>(id: id)
            try await engine.prepare(seed: seed)
            try engine.activate()
            XCTAssertEqual(try XCTUnwrap(engine.core).configuration, model.configuration, "seed \(seed) at start")

            var edited = model.configuration
            edited.paletteID = "ink"
            edited.boundaryMode = .open
            edited.brushRadius = 0.12
            edited.viscosity = 0.35
            edited.dyeDissipation = 3.5
            edited.velocityDissipation = 0.8
            edited.pressureIterations = 33
            model.configuration = edited
            model.setDetail(.high)
            for (control, values) in [("palette", [0.0]), ("edges", [1]), ("brush", [0.12]), ("viscosity", [0.35]),
                                      ("dyeFade", [3.5]), ("motionFade", [0.8]), ("quality", [33]), ("detail", [2])] {
                XCTAssertTrue(engine.handle(control: control, values: values).isAccepted, control)
            }
            XCTAssertEqual(try XCTUnwrap(engine.core).configuration, model.configuration, "seed \(seed) after edits")

            model.resetConfiguration()
            XCTAssertTrue(engine.handle(control: "tuningReset").isAccepted)
            var expected = model.configuration
            expected.seed = seed   // the standalone reset returns the seed to 1; the adapter keeps it (difference 3)
            XCTAssertEqual(try XCTUnwrap(engine.core).configuration, expected.validated().0, "seed \(seed) after reset")
        }
    }
}
