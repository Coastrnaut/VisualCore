// SolarQualityTests — feature 107 (A14-P05) T-A14-503 and T-A14-504 (FR-A14-503, FR-A14-510; SC-A14-504;
// clarifications Q3, Q5; contracts/review.md). The detail levels and the model statement inside the one app's session
// host on the simulator, short runs only (each test well under 10 s, no wall-clock assertion): the declared two levels
// agree with the drawing's levels and the profile's names; both levels draw a non-blank frame with the same body
// centres, camera, probes and state digest, and level 1 draws fewer vertices; a host tier above 1 draws level 1; a
// level change during a running focus flight or a running tour changes neither the state nor the flight's target
// (compared frame by frame with a run that keeps level 0); and the controls show "About this model" with the core's
// model statement.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class SolarQualityTests: XCTestCase {
    private let size = CGSize(width: 240, height: 160)

    /// An action sent before a given frame of a traced run.
    private struct Step {
        /// The control.
        let control: String
        /// Its values.
        let values: [Double]
    }

    /// What one frame of a traced run recorded.
    private struct Sample: Equatable {
        /// The state digest after the frame.
        let digest: String
        /// The flight's destination after the frame.
        let target: FocusFlight.View?
        /// The drawn body centres of the frame.
        let centers: [Vec3]
        /// The drawn camera of the frame.
        let camera: OrbitCamera?
    }

    /// Opens Solar System Explorer, then for each of `frames` frames sends the steps of that frame, switches to
    /// level 1 before frame `switchAt` (checking that the switch alone changes no digest and happens mid-flight) and
    /// draws the frame; returns what every frame recorded and the level the last frame drew.
    private func trace(frames: Int, switchAt: Int?, steps: [Int: [Step]],
                       tour: Bool) async throws -> (samples: [Sample], lastTier: Int?) {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let presenter = shell.presenter
        var samples: [Sample] = []
        for frame in 0..<frames {
            if let frameSteps = steps[frame] {
                for step in frameSteps {
                    XCTAssertTrue(shell.handle(control: step.control, values: step.values).isAccepted,
                                  "\(step.control) at frame \(frame)")
                }
            }
            if let switchAt, switchAt == frame {
                XCTAssertLessThan(presenter.flightFrame, FocusFlight.frameCount, "the switch happens mid-flight")
                if tour { XCTAssertGreaterThanOrEqual(try SolarTest.core(shell).state.tourIndex, 0, "a tour runs") }
                let before = try solarDigest(SolarTest.core(shell))
                let target = presenter.flight?.to
                try shell.setQualityTier(1)
                XCTAssertEqual(try solarDigest(SolarTest.core(shell)), before, "the switch alone changes no state")
                XCTAssertEqual(presenter.flight?.to, target, "the switch alone keeps the flight's target")
            }
            try SolarTest.frames(session, 1)
            samples.append(Sample(digest: try solarDigest(SolarTest.core(shell)), target: presenter.flight?.to,
                                  centers: presenter.lastCenters, camera: presenter.lastCamera))
        }
        let lastTier = presenter.lastTier
        session.close()
        return (samples, lastTier)
    }

    /// The declared levels, the drawing's levels and the profile's names agree (two, `level-0` and `level-1`).
    func testTheDeclaredLevelsAgreeEverywhere() async throws {
        XCTAssertEqual(SolarCore.qualityTiers, 2)
        XCTAssertEqual(SceneMeshes.DetailLevel.levels.count, SolarCore.qualityTiers)
        var names: [String] = []
        for level in SceneMeshes.DetailLevel.levels { names.append(level.name) }
        XCTAssertEqual(names, ["level-0", "level-1"])
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        XCTAssertEqual(shell.qualityProfile.names, ["level-0", "level-1"])
        XCTAssertEqual(shell.qualityProfile.levels.count, SolarCore.qualityTiers)
        XCTAssertEqual(shell.presenter.lastTier, 0, "the first frame is drawn at full detail")
        session.close()
    }

    /// The levels' meshes: level 1 has spheres of 24 × 12 with the recipe colours, the first 200 of the 400 stars and
    /// orbits of 64 samples that are every second point of level 0's; tiers clamp to 0 … 1.
    func testTheLevelOneMeshesAreCoarserSubsetsOfLevelZero() throws {
        let full = SceneMeshes.DetailLevel.levels[0], low = SceneMeshes.DetailLevel.levels[1]
        XCTAssertEqual(full.sphereSegments, 48)
        XCTAssertEqual(full.sphereRings, 24)
        XCTAssertEqual(full.starCount, 400)
        XCTAssertEqual(full.orbitSamples, 128)
        XCTAssertEqual(low.sphereSegments, 24)
        XCTAssertEqual(low.sphereRings, 12)
        XCTAssertEqual(low.starCount, 200)
        XCTAssertEqual(low.orbitSamples, 64)
        XCTAssertEqual(SceneMeshes.lowUnitSphere, Mesh.uvSphere(segments: 24, rings: 12, radius: 1))
        let bodies = SceneMeshes.bodies(sphere: SceneMeshes.lowUnitSphere)
        XCTAssertEqual(bodies.count, SolarCore.bodyCount)
        for index in 0..<bodies.count {
            XCTAssertEqual(bodies[index].colors, SceneMeshes.bodyColors(index: index, mesh: SceneMeshes.lowUnitSphere))
        }
        XCTAssertEqual(SceneMeshes.lowStarField.count, 200)
        XCTAssertEqual(SceneMeshes.lowStarField, Array(SceneMeshes.starField.prefix(200)))
        let modes: [ScaleMode] = [.enhanced, .trueRelative]
        for mode in modes {
            let fullPaths = SceneMeshes.orbitPaths(mode: mode)
            let lowPaths = SceneMeshes.orbitPaths(mode: mode, samples: OrbitLayout.lowOrbitSamples)
            XCTAssertEqual(lowPaths.count, fullPaths.count)
            for path in 0..<lowPaths.count {
                XCTAssertEqual(lowPaths[path].count, 64)
                for k in 0..<lowPaths[path].count {
                    let a = lowPaths[path][k], b = fullPaths[path][2 * k]
                    XCTAssertEqual((a - b).length, 0, accuracy: 1e-9, "\(mode) path \(path) point \(k)")
                }
            }
        }
        XCTAssertEqual(SceneMeshes.DetailLevel.index(tier: 0), 0)
        XCTAssertEqual(SceneMeshes.DetailLevel.index(tier: 1), 1)
        XCTAssertEqual(SceneMeshes.DetailLevel.index(tier: 5), 1, "above 1 draws level 1")
        XCTAssertEqual(SceneMeshes.DetailLevel.index(tier: -1), 0, "below 0 draws level 0")
    }

    /// Both levels draw a non-blank frame with the same centres, camera, probes and digest; level 1 draws fewer
    /// vertices; the renderers of both levels exist from the start and a level change makes none.
    func testBothLevelsDrawTheSamePositionsAndStateWithFewerVerticesAtLevelOne() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        for _ in 0..<4 { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        try SolarTest.frames(session, FocusFlight.frameCount)
        XCTAssertEqual(presenter.lowBodyRenderers.count, 9)
        XCTAssertEqual(presenter.lowOrbitRenderers.count, 8)
        XCTAssertEqual(presenter.lowTrueOrbitRenderers.count, 8)
        XCTAssertNotNil(presenter.lowStarRenderer)
        let builds = presenter.rendererBuildCount
        let meshes = presenter.meshBuildCount

        let full = try SolarTest.picture(session)
        XCTAssertEqual(presenter.lastTier, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(full.rgba, width: full.width, height: full.height), "level 0 not blank")
        XCTAssertFalse(FrameChecks.isBlack(full.rgba, width: full.width, height: full.height), "level 0 not black")
        let centers = presenter.lastCenters
        let camera = presenter.lastCamera
        let probes = shell.frameProbes
        let digest = try solarDigest(SolarTest.core(shell))
        let fullBodyVertices = presenter.lastBodyVertexCount
        let fullVertices = presenter.lastDetailVertexCount
        XCTAssertEqual(fullBodyVertices, 9 * 49 * 25)

        try shell.setQualityTier(1)
        let low = try SolarTest.picture(session)
        XCTAssertEqual(presenter.lastTier, 1)
        XCTAssertTrue(FrameChecks.isNonBlank(low.rgba, width: low.width, height: low.height), "level 1 not blank")
        XCTAssertFalse(FrameChecks.isBlack(low.rgba, width: low.width, height: low.height), "level 1 not black")
        XCTAssertEqual(presenter.lastCenters, centers, "the same drawn body positions")
        XCTAssertEqual(presenter.lastCamera, camera, "the same drawn camera")
        XCTAssertEqual(shell.frameProbes, probes, "the same probes")
        XCTAssertEqual(try solarDigest(SolarTest.core(shell)), digest, "the same state")
        XCTAssertEqual(presenter.lastBodyVertexCount, 9 * 25 * 13)
        XCTAssertLessThan(presenter.lastBodyVertexCount, fullBodyVertices)
        XCTAssertLessThan(presenter.lastDetailVertexCount, fullVertices)
        XCTAssertEqual(presenter.lastBodiesDrawn, 9)
        XCTAssertTrue(presenter.lastStarsDrawn)
        XCTAssertEqual(presenter.lastOrbitsDrawn, 8)

        try shell.setQualityTier(0)
        try SolarTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        XCTAssertEqual(presenter.lastBodyVertexCount, fullBodyVertices)
        XCTAssertEqual(presenter.rendererBuildCount, builds, "a level change makes no renderer")
        XCTAssertEqual(presenter.meshBuildCount, meshes, "nor any mesh")
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "every renderer of both levels released")
    }

    /// A level change during a running focus flight changes neither the state nor the flight's target, frame by frame
    /// against a run that keeps level 0.
    func testSwitchingTheLevelDuringAFocusFlightChangesNothingButTheMeshes() async throws {
        let steps: [Int: [Step]] = [0: [Step(control: "body.select", values: [5])]]
        let kept = try await trace(frames: 36, switchAt: nil, steps: steps, tour: false)
        let switched = try await trace(frames: 36, switchAt: 10, steps: steps, tour: false)
        XCTAssertEqual(kept.lastTier, 0)
        XCTAssertEqual(switched.lastTier, 1)
        XCTAssertEqual(switched.samples.count, kept.samples.count)
        for frame in 0..<kept.samples.count {
            XCTAssertEqual(switched.samples[frame], kept.samples[frame], "frame \(frame)")
        }
        let jupiter = OrbitLayout.scenePosition(index: 5, day: 0)
        XCTAssertEqual(switched.samples.last?.target?.target, jupiter, "the flight still ends at Jupiter")
    }

    /// A level change during a running tour changes neither the state nor the flight's target, frame by frame against
    /// a run that keeps level 0 (the tour also moves on to Saturn after the switch).
    func testSwitchingTheLevelDuringATourChangesNothingButTheMeshes() async throws {
        // The Giant planets tour starts at Jupiter, so its first flight runs when the level changes.
        let steps: [Int: [Step]] = [0: [Step(control: "tour.start", values: [1])],
                                    20: [Step(control: "tour.next", values: [])]]
        let kept = try await trace(frames: 40, switchAt: nil, steps: steps, tour: true)
        let switched = try await trace(frames: 40, switchAt: 10, steps: steps, tour: true)
        XCTAssertEqual(kept.lastTier, 0)
        XCTAssertEqual(switched.lastTier, 1)
        XCTAssertEqual(switched.samples.count, kept.samples.count)
        for frame in 0..<kept.samples.count {
            XCTAssertEqual(switched.samples[frame], kept.samples[frame], "frame \(frame)")
        }
        let saturn = OrbitLayout.scenePosition(index: 6, day: 0)
        XCTAssertEqual(switched.samples.last?.target?.target, saturn, "the tour's second stop is Saturn")
    }

    /// The controls show "About this model" with the core's model statement as label and value.
    func testTheControlsShowTheModelStatement() async throws {
        XCTAssertEqual(SolarControls.aboutLabel, "About this model")
        XCTAssertEqual(SolarControls.aboutText, ScientificReview.modelStatement)
        XCTAssertTrue(SolarControls.aboutText.contains("not an ephemeris"), SolarControls.aboutText)
        XCTAssertTrue(SolarControls.aboutText.contains("not to scale"), SolarControls.aboutText)
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        XCTAssertEqual(shell.port.identifier(SolarControls.aboutName),
                       "experience.a14.solar-system-explorer.about-model")
        XCTAssertNotNil(shell.presenter.makeControls(shell.port))
        session.close()
    }
}
