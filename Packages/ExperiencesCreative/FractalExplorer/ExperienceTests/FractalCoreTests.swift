// FractalCoreTests — feature 193 (UA-F07) T-U07-023 (FR-U07-001 to FR-U07-004; data-model section 2). The adapter core
// of Fractal Explorer against the experience contract: conformance, a size-independent framing, pan, pinch and the zoom
// buttons as normalized actions that match the standalone app's viewport arithmetic, the cap, palette, animation and
// seed, go-to numbers, tours and palette animation in fixed steps, the precision limit, bookmarks and the manifest.
// Host tests (`swift test`).
import Foundation
import Testing
@testable import FractalExplorerExperience
import FractalExplorerCore
import VisualCoreExperience
import VisualCoreMath

private let id = ExperienceID(rawValue: FractalCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<FractalCore> {
    var engine = ExperienceEngine<FractalCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<FractalCore>) throws -> FractalCore {
    try #require(engine.core)
}

private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-12) -> Bool {
    abs(a - b) <= tolerance * max(1, abs(a), abs(b))
}

@Suite struct FractalCoreTests {
    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 30,
            actions: [ScriptedAction("pan", [0.1, 0.2]), ScriptedAction("pinch", [1.7, -0.2, 0.1]),
                      ScriptedAction("zoomIn"), ScriptedAction("cap.up"), ScriptedAction("palette", [3]),
                      ScriptedAction("animate", [0]), ScriptedAction("mode", [1]), ScriptedAction("seed", [0.3, 0.5]),
                      ScriptedAction("tour.start", [0, 0]), ScriptedAction("goTo", [-0.5, 0.5, 10])],
            rejected: [ScriptedAction("mode", [0]), ScriptedAction("tour.stop"), ScriptedAction("palette", [7]),
                       ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(FractalCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func aPreparationIsTheStandaloneStart() async throws {
        let state = try core(try await engine())
        #expect(state.mode == .mandelbrot)
        #expect(state.framing == FractalCore.defaultFraming(.mandelbrot))
        #expect(state.juliaSeed == FractalState.defaultSeed && state.cap == 200 && state.radius == 2)
        #expect(state.paletteID == "sunset" && state.animate && state.tourIndex == nil)
        // The standalone state for any view size shows the same framing.
        for size in [Vec2(390, 844), Vec2(1024, 768), Vec2(300, 300)] {
            #expect(PlaneFraming(state.state(size: size).viewport) == state.framing)
            #expect(state.state(size: size) == FractalState(size: size))
        }
    }

    @Test func panAndPinchMatchTheStandaloneViewportForAnySize() async throws {
        for size in [Vec2(390, 844), Vec2(1024, 768)] {
            var engine = try await engine()
            var viewport = FractalState(size: size).viewport
            let side = min(size.x, size.y)
            // A drag of 40, −25 points and a pinch of 1.8 about a point off the centre, in view points.
            let drag = Vec2(40, -25), anchor = Vec2(size.x * 0.3, size.y * 0.6)
            viewport = viewport.panned(by: drag)
            viewport = viewport.pinched(by: 1.8, anchor: anchor)
            viewport = viewport.pinched(by: 2, anchor: size / 2)
            #expect(engine.handle(control: "pan", values: [drag.x / side, drag.y / side]) == .accepted)
            let offset = (anchor - size / 2) / side
            #expect(engine.handle(control: "pinch", values: [1.8, offset.x, offset.y]) == .accepted)
            #expect(engine.handle(control: "zoomIn") == .accepted)
            let framing = try core(engine).framing
            let expected = PlaneFraming(viewport)
            #expect(close(framing.center.x, expected.center.x), "\(size)")
            #expect(close(framing.center.y, expected.center.y), "\(size)")
            #expect(close(framing.span, expected.span), "\(size)")
        }
    }

    @Test func aCentredPinchKeepsTheCentre() async throws {
        var engine = try await engine()
        let centre = try core(engine).framing.center
        for _ in 0..<5 { #expect(engine.handle(control: "pinch", values: [2, 0, 0]) == .accepted) }
        #expect(try core(engine).framing.center == centre)
        #expect(close(try core(engine).zoom, 32))
        #expect(engine.handle(control: "zoomOut") == .accepted)
        #expect(close(try core(engine).zoom, 16))
        #expect(engine.handle(control: "resetView") == .accepted)
        #expect(try core(engine).framing == FractalCore.defaultFraming(.mandelbrot))
    }

    @Test func capPaletteAnimationAndSeedAreActions() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "cap.up") == .accepted)
        #expect(try core(engine).cap == 400)
        #expect(engine.handle(control: "cap.down") == .accepted)
        #expect(engine.handle(control: "cap.down") == .accepted)
        #expect(try core(engine).cap == 100)
        #expect(engine.handle(control: "cap", values: [10_000]) == .accepted)
        #expect(engine.handle(control: "cap.up") == .accepted)
        #expect(try core(engine).cap == CapControl.maximum)
        #expect(engine.handle(control: "palette", values: [4]) == .accepted)
        #expect(try core(engine).paletteID == "ember")
        #expect(engine.handle(control: "seed", values: [0.285, 0.01]) == .accepted)
        #expect(try core(engine).juliaSeed == Vec2(0.285, 0.01))
        #expect(engine.handle(control: "mode", values: [1]) == .accepted)
        #expect(try core(engine).framing == FractalCore.defaultFraming(.julia), "a new family reframes")
        #expect(engine.handle(control: "seed", values: [5, 0]) == .rejected(.outOfRange(index: 0)))
    }

    @Test func paletteAnimationAdvancesOnlyWithSteps() async throws {
        var engine = try await engine()
        #expect(try core(engine).paletteTime == 0)
        try engine.run(steps: 240)
        #expect(close(try core(engine).paletteTime, 2, 1e-9))
        #expect(engine.handle(control: "animate", values: [0]) == .accepted)
        try engine.run(steps: 240)
        #expect(close(try core(engine).paletteTime, 2, 1e-9), "paused animation keeps its time")
    }

    @Test func toursAdvanceWithStepsAndEndOnInteraction() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "tour.start", values: [0, 0]) == .accepted)
        let tour = FractalTours.all[0]
        let timeline = tour.timeline(from: FractalCore.defaultFraming(.mandelbrot), reduceMotion: false)
        try engine.run(steps: 600)   // 5 s: past the first 4 s flight, holding at stop 0
        var state = try core(engine)
        let expected = timeline.state(at: 5)
        #expect(close(state.framing.center.x, expected.framing.center.x))
        #expect(close(state.framing.span, expected.framing.span))
        #expect(state.tourStop == 0 && state.tourCaption == tour.stops[0].caption && state.tourPlaying)
        let total = Int(((FractalTour.flightSeconds + FractalTour.holdSeconds) * Double(tour.stops.count) + 1) * 120)
        try engine.run(steps: total)
        state = try core(engine)
        #expect(!state.tourPlaying, "the tour finished")
        #expect(state.tourCaption == tour.stops.last?.caption)
        #expect(engine.handle(control: "pan", values: [0.1, 0]) == .accepted)
        #expect(try core(engine).tourCaption == nil, "an interaction clears the tour")
        #expect(engine.handle(control: "tour.stop") == .rejected(.rule(code: "a03.no-tour")))
    }

    @Test func goToTakesNumbersAndThePrecisionLimitClampsTheSpan() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "goTo", values: [-0.75, 0.1, 8]) == .accepted)
        var state = try core(engine)
        #expect(state.framing == PlaneFraming(center: Vec2(-0.75, 0.1), span: 0.5))
        #expect(!state.limitReached)
        #expect(engine.handle(control: "goTo", values: [-0.743643887, 0.131825904, 1e15]) == .accepted)
        state = try core(engine)
        #expect(state.limitReached)
        #expect(state.framing.span == FractalCore.minimumSpan(at: state.framing.center))
        #expect(state.outcome?.code == "deep-zoom")
        // The controls parse text with the app's own parser and send its numbers.
        guard case .success(let target) = GoToInput.parse(real: "-0.5", imaginary: "0.25", zoom: "4",
                                                          locale: Locale(identifier: "en_US")) else {
            Issue.record("the app's parser refused valid text")
            return
        }
        #expect(engine.handle(control: "goTo", values: [target.center.x, target.center.y, target.zoom]) == .accepted)
        #expect(try core(engine).framing == target.framing(for: .mandelbrot))
    }

    @Test func aBookmarkOpensToItsView() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "bookmark.open", values: [1, 0.1, -0.2, 0.75, -0.4, 0.6, 400, 3]) == .accepted)
        let state = try core(engine)
        #expect(state.mode == .julia && state.juliaSeed == Vec2(-0.4, 0.6) && state.cap == 400)
        #expect(state.paletteID == "neon")
        #expect(state.framing == PlaneFraming(center: Vec2(0.1, -0.2), span: 0.75))
    }

    @Test func theSnapshotRoundTripGivesTheSameDigest() async throws {
        var engine = try await engine(seed: 99)
        for (control, values) in [("pan", [0.2, 0.1]), ("tour.start", [1.0, 1]), ("palette", [1]),
                                  ("cap.up", [])] {
            #expect(engine.handle(control: control, values: values) == .accepted, "\(control)")
            try engine.run(steps: 37)
        }
        let digest = try engine.digest()
        let snapshot = try engine.snapshot()
        var restored = ExperienceEngine<FractalCore>(id: id)
        try await restored.prepare(seed: 99)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == digest)
        #expect(try core(restored) == core(engine))
    }
}

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<FractalCore>(id: id)
    try await engine.prepare(seed: spec.seed)
    try engine.activate()
    let initial = try engine.digest().hex
    var results: [String] = []
    for entry in spec.entries {
        try engine.run(steps: entry.steps)
        if let action = entry.action {
            results.append(engine.handle(control: action.control, values: action.values).code)
        }
    }
    return (initial, results, try engine.digest().hex)
}

@Suite struct FractalManifestTests {
    @Test func theManifestIsValidWithFiveFixtures() {
        let manifest = FractalCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: FractalCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func committedDigestsAndResultsAreWhatTheEngineGives() async throws {
        for spec in FractalCore.manifest(for: id).scenarios {
            let played = try await play(spec)
            if let initial = spec.expect.initialDigest {
                #expect(played.initial == initial, "\(spec.name) initial: \(played.initial)")
            }
            if let final = spec.expect.finalDigest {
                #expect(played.final == final, "\(spec.name) final: \(played.final)")
            }
            let expected = spec.entries.compactMap { $0.action == nil ? nil : ($0.result ?? "accepted") }
            #expect(played.results == expected, "\(spec.name)")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1 swift
    /// test` rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = FractalCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = FractalCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run UPDATE_SCENARIO_MANIFEST=1 swift test and commit the file")
    }
}
