// SolarCore — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5; contracts/catalog.md), with the
// orbit view's date and camera by feature 104 (A14-P02) T-A14-208 (FR-A14-211, FR-A14-221, FR-A14-222; clarifications
// Q3–Q5; contracts/orbit-view.md), with the scale mode by feature 105 (A14-P03) T-A14-306 (FR-A14-310, FR-A14-312;
// clarification Q3; contracts/bodies.md), with the clock, tours and saved views by feature 106 (A14-P04) T-A14-406
// (FR-A14-401–403, FR-A14-411, FR-A14-421; clarifications Q1, Q2, Q5; contracts/time-tours.md). The state of Solar System Explorer as an experience: a `SolarState` (schema 2: the
// selected and focused body, 0 = Sun … 8 = Neptune, into `BodyCatalog.bundled`; the simulated date in days since
// J2000.0; the camera's yaw, pitch and zoom steps) and the preparation seed. Nothing animates: a host step (the
// default 1/120 s) changes nothing, so a suspension never changes the view either.
//
// Preparation (A14-P04: a host step now advances the clock and the tour, see the actions below): every preparation seed opens with the Sun selected at J2000.0 with the overview camera
// (`SolarState.initial`); the seed is kept only as the envelope's preparation seed (`reset()` returns to the same first
// state). The catalog and the orbital elements are fixed data, so nothing depends on the seed.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   body.select [0…8]       the body by catalog index; a value that is not a whole index 0…8 is refused with
//                           `a14.invalid-choice`.
//   body.next               the next body (refused with `a14.invalid-choice` at Neptune).
//   body.previous           the previous body (refused with `a14.invalid-choice` at the Sun).
//   date.step [−365…365]    steps the date by ±1, ±30 or ±365 days; another value is refused with `a14.invalid-step`,
//                           a step leaving 1950-01-01 … 2051-01-01 (days −18,262.5 … 18,627.5) with `a14.out-of-range`.
//   camera.orbit [−1…1]     turns the camera by one 15° step; a value other than ±1 is refused with `a14.invalid-step`.
//   camera.tilt [−1…1]      tilts by 10° within 5°…85°; beyond is refused with `a14.out-of-range`, a value other
//                           than ±1 with `a14.invalid-step`.
//   camera.zoom [−1…1]      +1 closer, −1 farther, zoom steps −1…12; beyond is refused with `a14.out-of-range`, a
//                           value other than ±1 with `a14.invalid-step`.
//   view.reset              the overview camera (yaw 0, pitch 35°, zoom 0); the selection, date and scale stay.
//   scale.mode [0…1]        0 enhanced, 1 true-relative (`ScaleMode`); a value that is not a whole 0 or 1 is refused
//                           with `a14.invalid-choice`.
//   time.play [0…1]         pauses (0) or plays (1) simulated time; a non-whole value `a14.invalid-choice`.
//   time.rate [0…3]         the rate (`SimClock.rates`, 1 day to 1 year per second); non-whole `a14.invalid-choice`.
//   date.set [days]         the date ("Now", computed by the controls from an injected clock); a non-finite value or one
//                           outside the range `a14.out-of-range`.
//   tour.start [0…1]        starts (or restarts) tour 0 or 1 at its first stop; non-whole `a14.invalid-choice`.
//   tour.next, tour.stop    the next stop (after the last the tour ends), or the end of the tour; `a14.no-tour` without
//   tour.pause [0…1]        a tour; pause holds or resumes the tour.
//   view.apply [7 values]   a saved view (selection, day, rate, yaw, pitch, zoom, scale; `SavedView`); a value off its
//                           range `a14.out-of-range`; it ends a tour and pauses time.
// Body choices (`body.select`, `body.next`, `body.previous`) during a tour end the tour. A host step advances the state
// (`SolarState.advance()`: the clock while playing, then the tour), so motion and tours are replayable and a suspension
// (no steps) never fast-forwards them.
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 4: `SolarState.encoded()` (JSON with sorted keys, the fields of `SolarState`); the preparation seed
// and the schema version come from the snapshot envelope (`MigrationChain(currentVersion: 4)` with the steps 1 → 2
// adding J2000.0 and the overview camera, 2 → 3 adding the enhanced scale mode and 3 → 4 adding a paused clock at
// rate 0 and no tour, so older envelopes open and a newer envelope is refused by the engine). The engine refuses a
// value outside a declared range (for `date.set` the model's range, for `view.apply` each field's range) with
// `action.out-of-range` before the core sees it. A payload
// `SolarState.decode(_:)` refuses (damaged, newer inside the payload or out of range) is refused (the restore throws
// `SolarRestoreError`). One
// quality tier (`level-0`). The digest is the canonical text of the state ("a14.solar.v4|" and the state's JSON)
// followed by the selection and the selected body's id.
//
// The outcome is `viewing-<body id>` ("viewing-sun", "viewing-earth") for the selected body: the scenario manifest's
// completion scenario must expect an outcome (`ScenarioManifestValidator`), and focusing a body is what a session of
// this phase completes, as Tiny Worlds' `world-<preset>` outcome is.
//
// The canvas description (clarifications Q4, Q5; A14-P03 Q3): "Solar System Explorer: Earth in focus on 2000-01-01,
// 0.983 AU (147,101,000 km) from the Sun; 9 bodies. Distances and sizes not to scale." (for the Sun: "Sun in focus on
// 2000-01-01; 9 bodies. …"); the last sentence is the scale mode's label, so in the true-relative mode it ends
// "Distances and sizes to one scale; small bodies marked." Distances are the approximate model's, in AU to three decimals and in km rounded to the
// thousand through 1 AU = 149,597,870.7 km.
import Foundation
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Solar System Explorer's refusals.
public enum SolarRule {
    /// A body index that is not a whole index 0…8, or a step past the first or the last body.
    public static let invalidChoice = "a14.invalid-choice"
    /// A date step other than ±1, ±30 or ±365 days, or a camera step other than ±1.
    public static let invalidStep = DateStepRefusal.invalidStep.rawValue
    /// A date step leaving the model's range, or a tilt or zoom step beyond its range.
    public static let outOfRange = DateStepRefusal.outOfRange.rawValue
    /// A tour action without a running tour (A14-P04).
    public static let noTour = "a14.no-tour"
}

/// Why a stored Solar System Explorer state is refused.
public enum SolarRestoreError: Error, Equatable {
    /// `SolarState.decode(_:)` refused the payload, for the named reason.
    case refused(SolarStateRefusal)
}

/// The state of Solar System Explorer. Schema version 2.
public struct SolarCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a14.solar-system-explorer"

    /// The action ids in declaration order.
    public static let actionIDs = ["body.select", "body.next", "body.previous", "date.step", "camera.orbit",
                                   "camera.tilt", "camera.zoom", "view.reset", "scale.mode", "time.play", "time.rate",
                                   "date.set", "tour.start", "tour.next", "tour.pause", "tour.stop", "view.apply"]

    /// The value count of each action.
    static let valueCounts: [String: Int] = ["body.select": 1, "body.next": 0, "body.previous": 0, "date.step": 1,
                                             "camera.orbit": 1, "camera.tilt": 1, "camera.zoom": 1,
                                             "view.reset": 0, "scale.mode": 1, "time.play": 1, "time.rate": 1,
                                             "date.set": 1, "tour.start": 1, "tour.next": 0, "tour.pause": 1,
                                             "tour.stop": 0, "view.apply": SavedView.valueCount]

    /// The approximate orbit model of the bundled catalog and elements.
    public static let model = OrbitModel.bundled

    /// The prefix of the outcome code; the selected body's id follows.
    public static let outcomePrefix = "viewing-"

    /// The enhanced mode's label, which the canvas description ends with in that mode.
    public static let notToScale = ScaleMode.enhanced.label

    /// The catalog the selection refers to.
    public static var catalog: BodyCatalog { SolarState.catalog }

    /// The number of bodies of the catalog (9).
    public static var bodyCount: Int { SolarState.bodyCount }

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: the selected body, the date and the camera.
    public private(set) var state: SolarState

    /// The first state (the Sun selected at J2000.0, overview camera) with `seed` as preparation seed.
    public init(seed: UInt64) {
        self.init(seed: seed, state: .initial)
    }

    /// A core holding `state`, prepared with `seed`.
    init(seed: UInt64, state: SolarState) {
        preparationSeed = seed
        self.state = state
    }

    /// The selected body's index, 0 (the Sun) … 8 (Neptune).
    public var selection: Int { state.selection }
    /// The selected body; nil only if the catalog lacked the index (never for a decoded state).
    public var body: CelestialBody? { Self.catalog.body(at: state.selection) }
    /// The selected body's fact card.
    public var factCard: FactCard? { Self.catalog.factCard(for: state.selection) }

    // MARK: Contract

    /// Two quality tiers (A14-P05, T-A14-504): `level-0` (spheres 48 × 24, 400 stars, orbits of 128 samples) and
    /// `level-1` (24 × 12, 200 stars, 64 samples); a level changes only the drawing, never a position or the state.
    public static var qualityTiers: Int { 2 }

    /// Schema 4 with the steps 1 → 2 (J2000.0 and the overview camera), 2 → 3 (the enhanced scale mode) and 3 → 4 (a
    /// paused clock at rate 0, no tour).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: SolarState.schemaVersion, steps: [1: { payload in
            var next = payload
            next["schema"] = 2
            next["dayOffset"] = 0.0
            next["yawSteps"] = 0
            next["pitchDegrees"] = SolarState.overviewPitch
            next["zoomSteps"] = 0
            return next
        }, 2: { payload in
            var next = payload
            next["schema"] = 3
            next["scaleMode"] = ScaleMode.enhanced.rawValue
            return next
        }, 3: { payload in
            var next = payload
            next["schema"] = 4
            next["playing"] = false
            next["rateIndex"] = 0
            next["stopReason"] = ""
            next["tourIndex"] = -1
            next["tourStop"] = 0
            next["tourStep"] = 0
            next["tourPaused"] = false
            return next
        }])
    }

    /// The seventeen controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "body.select", ranges: [0...Double(bodyCount - 1)]),
         ExperienceControl(id: "body.next"),
         ExperienceControl(id: "body.previous"),
         ExperienceControl(id: "date.step", ranges: [-365...365]),
         ExperienceControl(id: "camera.orbit", ranges: [-1...1]),
         ExperienceControl(id: "camera.tilt", ranges: [-1...1]),
         ExperienceControl(id: "camera.zoom", ranges: [-1...1]),
         ExperienceControl(id: "view.reset"),
         ExperienceControl(id: "scale.mode", ranges: [0...1]),
         ExperienceControl(id: "time.play", ranges: [0...1]),
         ExperienceControl(id: "time.rate", ranges: [0...Double(SimClock.rates.count - 1)]),
         ExperienceControl(id: "date.set", ranges: [SimulatedDate.range]),
         ExperienceControl(id: "tour.start", ranges: [0...Double(Tour.bundled.count - 1)]),
         ExperienceControl(id: "tour.next"),
         ExperienceControl(id: "tour.pause", ranges: [0...1]),
         ExperienceControl(id: "tour.stop"),
         ExperienceControl(id: "view.apply", ranges: viewApplyRanges)]
    }

    /// The declared ranges of `view.apply`'s seven values (selection, day, rate, yaw steps, pitch, zoom, scale).
    static var viewApplyRanges: [ClosedRange<Double>] {
        [0...Double(bodyCount - 1), SimulatedDate.range, 0...Double(SimClock.rates.count - 1), -1_000_000...1_000_000,
         Double(SolarState.pitchRange.lowerBound)...Double(SolarState.pitchRange.upperBound),
         Double(SolarState.zoomRange.lowerBound)...Double(SolarState.zoomRange.upperBound), 0...1]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> SolarCore {
        try Task.checkCancellation()
        return SolarCore(seed: seed)
    }

    /// A host step advances the clock while playing and a running tour (`SolarState.advance()`).
    public mutating func update(step: Int) {
        state.advance()
    }

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        func rule(_ code: String) -> ActionResult { .rejected(.rule(code: code)) }
        var next = state
        switch action.control {
        case "body.select":
            guard let index = Self.choice(v[0], count: Self.bodyCount), next.select(index) else {
                return rule(SolarRule.invalidChoice)
            }
            next.stopTour()
        case "body.next":
            guard next.next() else { return rule(SolarRule.invalidChoice) }
            next.stopTour()
        case "body.previous":
            guard next.previous() else { return rule(SolarRule.invalidChoice) }
            next.stopTour()
        case "time.play":
            guard let on = Self.whole(v[0]), on == 0 || on == 1 else { return rule(SolarRule.invalidChoice) }
            next.setPlaying(on == 1)
        case "time.rate":
            guard let index = Self.whole(v[0]), next.setRate(index) else { return rule(SolarRule.invalidChoice) }
        case "date.set":
            guard next.setDate(v[0]) else { return rule(SolarRule.outOfRange) }
        case "tour.start":
            guard let index = Self.whole(v[0]), next.startTour(index) else { return rule(SolarRule.invalidChoice) }
        case "tour.next":
            guard next.nextTourStop() else { return rule(SolarRule.noTour) }
        case "tour.pause":
            guard let on = Self.whole(v[0]), on == 0 || on == 1 else { return rule(SolarRule.invalidChoice) }
            guard next.pauseTour(on == 1) else { return rule(SolarRule.noTour) }
        case "tour.stop":
            guard next.tour != nil else { return rule(SolarRule.noTour) }
            next.stopTour()
        case "view.apply":
            guard let view = SavedView(values: v) else { return rule(SolarRule.outOfRange) }
            next.apply(view)
        case "date.step":
            guard let days = Self.whole(v[0]) else { return rule(SolarRule.invalidStep) }
            if let refusal = next.stepDate(by: days) { return rule(refusal.rawValue) }
        case "view.reset":
            next.resetView()
        case "scale.mode":
            guard let raw = Self.whole(v[0]), let mode = ScaleMode(rawValue: raw) else {
                return rule(SolarRule.invalidChoice)
            }
            next.setScaleMode(mode)
        default:   // camera.orbit, camera.tilt, camera.zoom
            guard let step = Self.whole(v[0]), step == 1 || step == -1 else { return rule(SolarRule.invalidStep) }
            let accepted: Bool
            switch action.control {
            case "camera.orbit": accepted = next.orbit(step)
            case "camera.tilt": accepted = next.tilt(step)
            default: accepted = next.zoom(step)
            }
            guard accepted else { return rule(SolarRule.outOfRange) }
        }
        state = next
        return .accepted
    }

    /// `value` as a whole number when it is finite and whole, nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded(), abs(value) <= 1_000_000 else { return nil }
        return Int(value)
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `viewing-<id>` of the selected body (see the file header).
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.outcomePrefix + (body?.id ?? "unknown"))
    }

    /// Back to the first state.
    public mutating func reset() {
        self = SolarCore(seed: preparationSeed)
    }

    /// The canonical text of the state, then the selection and the selected body's id.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a14.solar.v3|" + text)
        builder.add(state.selection)
        builder.add(body?.id ?? "")
    }

    /// The state (schema 2) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-2 (or migrated schema-1) payload with the envelope's `seed` as preparation seed; a payload that
    /// `SolarState.decode(_:)` refuses (damaged, newer or out of range) throws ``SolarRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> SolarCore {
        switch SolarState.decode(payload) {
        case .success(let state): return SolarCore(seed: seed, state: state)
        case .failure(let reason): throw SolarRestoreError.refused(reason)
        }
    }

    // MARK: Words

    /// The name of the body at `index` ("Earth"), or "Unknown body" outside the catalog.
    public static func name(index: Int) -> String {
        catalog.body(at: index)?.name ?? "Unknown body"
    }

    /// The status line: "Earth selected, body 4 of 9".
    public static func status(selection: Int) -> String {
        "\(name(index: selection)) selected, body \(selection + 1) of \(bodyCount)"
    }

    /// The distance of body `index` from the Sun on day `dayOffset` as words: "0.983 AU (147,101,000 km)"; nil for
    /// the Sun or an unknown index.
    public static func distanceWords(index: Int, dayOffset: Double) -> String? {
        guard let body = catalog.body(at: index), body.kind == .planet,
              let au = model.distanceAU(bodyID: body.id, day: dayOffset),
              let km = model.distanceKm(bodyID: body.id, day: dayOffset) else { return nil }
        let kmText = Units.storedText((km / 1000).rounded() * 1000)
        return String(format: "%.3f AU", au) + " (\(kmText) km)"
    }

    /// The canvas description: "Solar System Explorer: Earth in focus on 2000-01-01, 0.983 AU (147,101,000 km) from
    /// the Sun; 9 bodies. Distances and sizes not to scale."
    public static func canvasDescription(selection: Int, dayOffset: Double = 0, scaleMode: ScaleMode = .enhanced)
        -> String {
        let date = SimulatedDate(dayOffset: dayOffset)?.label ?? SimulatedDate.j2000.label
        let distance = distanceWords(index: selection, dayOffset: dayOffset).map { ", \($0) from the Sun" } ?? ""
        return "Solar System Explorer: \(name(index: selection)) in focus on \(date)\(distance); \(bodyCount) bodies. "
            + "\(scaleMode.label)."
    }

    /// The time words (A14-P04): "Date 2000-01-01 12:00 UTC, time paused." or "Date …, time playing at 1 year/s.",
    /// followed by "The model's range ends here." after motion stopped at a range end.
    public static func timeWords(state: SolarState) -> String {
        let date = state.date.labelWithTime
        let rate = SimClock.rateLabels.indices.contains(state.rateIndex) ? SimClock.rateLabels[state.rateIndex] : ""
        let motion = state.playing ? "time playing at \(rate)" : "time paused"
        let stop = state.stopReason == SimClock.endOfRange ? " \(SimClock.stopSentence)." : ""
        return "Date \(date), \(motion).\(stop)"
    }

    /// The tour words (A14-P04): "Tour Inner planets, stop 2 of 5: <caption>" (with "paused" when held), or nil
    /// without a tour.
    public static func tourWords(state: SolarState) -> String? {
        guard let tour = state.tour, let caption = state.tourCaption else { return nil }
        let held = state.tourPaused ? ", paused" : ""
        return "Tour \(tour.title), stop \(state.tourStop + 1) of \(tour.stops.count)\(held): \(caption)"
    }

    /// The canvas description of this core: the body, date, distance and scale sentence, then the time words and,
    /// during a tour, the tour words.
    public var canvasDescription: String {
        let base = Self.canvasDescription(selection: state.selection, dayOffset: state.dayOffset,
                                          scaleMode: state.scaleMode)
        let tour = Self.tourWords(state: state).map { " \($0)" } ?? ""
        return base + " " + Self.timeWords(state: state) + tour
    }
}
