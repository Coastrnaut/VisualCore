// SimulationRenderTests — feature 117 (A16-P01) T-A16-105 (FR-A16-130; SC-A16-105; plan "Lifecycle"). Simulation Lab
// rendered inside the one app's session host on the simulator off screen, short runs only (each test under 10 s, no
// wall-clock assertion; the simulation is paused first so frames stop advancing it): every family draws a non-blank,
// non-black frame with its background probe holding; changing the family changes the drawn pixels and the
// description; drawing never changes the state or its digest; a context recreation makes the target and the pass once
// more, uploads the CPU field again and draws the same frame; the grid is drawn in a centred square with crisp cells
// in the palette's exact colours; and the palette maps each family as documented.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation

/// Simulation Lab drawn through the session host.
@MainActor
final class SimulationRenderTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    /// Checks that `frame` is non-blank, not black and that every probe of `shell` holds on it.
    private func assertDrawn(_ shell: ExperienceShell<SimulationPresenter>, _ frame: SimulationFrame, _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        let probes = shell.frameProbes
        XCTAssertEqual(probes.map(\.name), ["background"], name)
        for probe in probes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testEveryFamilyDrawsANonBlankFrame() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        try SimulationTest.pause(shell)
        var hashes: Set<String> = []
        for (index, kind) in SimulationCore.families.enumerated() {
            XCTAssertTrue(shell.handle(control: "sim.family", values: [Double(index)]).isAccepted)
            let frame = try SimulationTest.picture(session)
            assertDrawn(shell, frame, kind.rawValue)
            XCTAssertEqual(shell.presenter.lastKind, kind)
            XCTAssertEqual(shell.presenter.lastField, try SimulationTest.core(shell).model.field)
            hashes.insert(StableHash.sha256Hex(frame.rgba))
        }
        XCTAssertEqual(hashes.count, 3, "every family draws its own frame")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testChangingTheFamilyChangesThePixelsAndTheDescription() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        try SimulationTest.pause(shell)
        let before = try SimulationTest.picture(session)
        let description = shell.accessibilitySummary
        XCTAssertTrue(shell.handle(control: "sim.family", values: [1]).isAccepted)
        let after = try SimulationTest.picture(session)
        assertDrawn(shell, after, "reaction-diffusion")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(SimulationTest.differingPixels(before.rgba, after.rgba), 100, "many pixels change")
        XCTAssertNotEqual(shell.accessibilitySummary, description, "the description changes")
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Simulation Lab: reaction-diffusion, preset Spots"),
                      shell.accessibilitySummary)
        let again = try SimulationTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(after.rgba), StableHash.sha256Hex(again.rgba), "a paused state holds")
        session.close()
    }

    func testDrawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "sim.family", values: [2]).isAccepted)
        try SimulationTest.pause(shell)
        let core = try SimulationTest.core(shell)
        let digest = try shell.engine.digest()
        let uploads = shell.presenter.uploadCount
        try SimulationTest.frames(session, 10)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try SimulationTest.core(shell), core, "the presenter reads the core only")
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertLessThanOrEqual(shell.presenter.uploadCount, uploads + 1, "an unchanged field is uploaded once")

        // Describing a core in a presenter of its own leaves the value as it was.
        let presenter = SimulationPresenter(experienceID: SimulationTest.id)
        let copy = core
        XCTAssertEqual(presenter.describe(core), core.canvasDescription)
        XCTAssertEqual(core, copy)
        XCTAssertEqual(presenter.probes(core), [], "no probe before the first frame")
        XCTAssertEqual(presenter.mirror.familyTitle, "Wave field", "describing syncs the mirror")
        session.close()
    }

    func testAContextRecreationDrawsTheSameFrame() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "sim.family", values: [2]).isAccepted)
        try SimulationTest.pause(shell)
        let presenter = shell.presenter
        let before = try SimulationTest.picture(session)
        let builds = presenter.resourceBuildCount
        let uploads = presenter.uploadCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        let after = try SimulationTest.picture(session)
        XCTAssertEqual(presenter.resourceBuildCount, builds + 1, "the target and the pass are made once more")
        XCTAssertGreaterThan(presenter.uploadCount, uploads, "the CPU field is uploaded into the new target")
        XCTAssertEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the same frame")
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
        XCTAssertNil(presenter.target)
    }

    func testTheGridIsDrawnInACentredSquareWithCrispCells() async throws {
        let square = SimulationPresenter.square(width: 240, height: 160, grid: 64)
        XCTAssertEqual(square.side, 128)
        XCTAssertEqual(square.x, 56)
        XCTAssertEqual(square.y, 16)
        let tiny = SimulationPresenter.square(width: 50, height: 40, grid: 64)
        XCTAssertEqual(tiny.side, 36, "below one pixel per cell the square keeps 92 % of the shorter side")

        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        try SimulationTest.pause(shell)
        let frame = try SimulationTest.picture(session)
        let drawn = try XCTUnwrap(shell.presenter.lastSquare)
        XCTAssertEqual(drawn.side.truncatingRemainder(dividingBy: 64), 0, "whole pixels per cell")
        let field = try SimulationTest.core(shell).model.field
        let cells = [(0, 0), (63, 63), (31, 17), (5, 50)]
        for (cx, cy) in cells {
            let px = Int(drawn.x + (Double(cx) + 0.5) * drawn.side / 64)
            let py = Int(drawn.y + (Double(cy) + 0.5) * drawn.side / 64)
            let index = (py * frame.width + px) * 4
            let expected = SimulationPalette.color(field.current, cell: cy * 64 + cx, kind: .automaton)
            XCTAssertLessThanOrEqual(abs(Int(frame.rgba[index]) - Int(expected.r)), 2, "cell \(cx), \(cy) red")
            XCTAssertLessThanOrEqual(abs(Int(frame.rgba[index + 1]) - Int(expected.g)), 2, "cell \(cx), \(cy) green")
            XCTAssertLessThanOrEqual(abs(Int(frame.rgba[index + 2]) - Int(expected.b)), 2, "cell \(cx), \(cy) blue")
        }
        let corner = SimulationPalette.background
        XCTAssertLessThanOrEqual(abs(Int(frame.rgba[0]) - Int(corner.r)), 2, "the margin is the background")
        session.close()
    }

    func testThePaletteMapsEachFamily() throws {
        XCTAssertTrue(SimulationPalette.automatonColor(1) == SimulationPalette.alive)
        XCTAssertTrue(SimulationPalette.automatonColor(0) == SimulationPalette.dead)
        let alive = SimulationPalette.alive, dead = SimulationPalette.dead, background = SimulationPalette.background
        XCTAssertEqual(FrameChecks.classify(r: alive.r, g: alive.g, b: alive.b), .green, "alive is bright")
        XCTAssertEqual(FrameChecks.classify(r: dead.r, g: dead.g, b: dead.b), .dark, "dead is dark")
        XCTAssertEqual(FrameChecks.classify(r: background.r, g: background.g, b: background.b), .dark)
        let stops = SimulationPalette.reactionStops
        XCTAssertTrue(SimulationPalette.reactionColor(v: 0) == stops[0])
        XCTAssertTrue(SimulationPalette.reactionColor(v: 0.25) == stops[1])
        XCTAssertTrue(SimulationPalette.reactionColor(v: 0.5) == stops[2])
        XCTAssertTrue(SimulationPalette.reactionColor(v: 0.9) == stops[2], "clamped above")
        XCTAssertTrue(SimulationPalette.waveColor(0) == SimulationPalette.waveZero)
        XCTAssertTrue(SimulationPalette.waveColor(1) == SimulationPalette.wavePositive)
        XCTAssertTrue(SimulationPalette.waveColor(-1) == SimulationPalette.waveNegative)
        XCTAssertTrue(SimulationPalette.waveColor(3) == SimulationPalette.wavePositive, "clamped above")
        XCTAssertTrue(SimulationPalette.waveColor(.nan) == SimulationPalette.waveZero, "NaN reads as 0")
        let half = SimulationPalette.waveColor(0.5)
        XCTAssertGreaterThan(half.r, SimulationPalette.waveZero.r)
        XCTAssertLessThan(half.r, SimulationPalette.wavePositive.r)
        for kind in SimulationKind.allCases {
            let spec = SimulationSpec.standard(kind, seed: 1)
            let pixels = SimulationPalette.rgba(Seeding.start(for: spec), kind: kind)
            XCTAssertEqual(pixels.count, 64 * 64 * 4, kind.rawValue)
            var alphas = true
            for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] != 255 { alphas = false }
            XCTAssertTrue(alphas, "\(kind.rawValue): opaque")
            XCTAssertTrue(FrameChecks.isNonBlank(pixels, width: 64, height: 64), "\(kind.rawValue): the start shows")
            let floats = SimulationPalette.floats(pixels)
            XCTAssertEqual(floats.count, pixels.count)
            XCTAssertEqual(floats[0], Float(pixels[0]) / 255)
        }
    }
}
