// SolarState — feature 103 (A14-P01) T-A14-102 (FR-A14-121; clarification Q5; data-model "SolarState";
// contracts/catalog.md), schema 2 by feature 104 (A14-P02) T-A14-206 (FR-A14-211, FR-A14-221, FR-A14-222;
// clarifications Q3–Q5; contracts/orbit-view.md), schema 3 by feature 105 (A14-P03) T-A14-305 (FR-A14-310,
// FR-A14-330; the scale mode), schema 4 by feature 106 (A14-P04) T-A14-405 (FR-A14-401, FR-A14-402, FR-A14-411,
// FR-A14-430; clarifications Q1, Q2, Q5: the simulated clock and the guided tour). The saved state of Solar System
// Explorer at snapshot schema 4: the selected (and focused) body index (0 = Sun … 8 = Neptune, an index into
// `BodyCatalog.bundled`), the simulated date (days since J2000.0, `SimulatedDate`), the camera (yaw in whole 15° steps,
// unbounded; pitch 5…85 on the grid 5 + 10k; zoom steps −1…12, distance 60 × 1.25^−n), the scale mode (`ScaleMode`),
// the clock (`playing`, `rateIndex` into `SimClock.rates`, `stopReason` "" or "end-of-range") and the tour (`tourIndex`
// into `Tour.bundled` or −1, `tourStop`, `tourStep` 0 ..< the stop's hold, `tourPaused`). The initial state selects the
// Sun at J2000.0 with the overview camera (yaw 0, pitch 35°, zoom 0), the enhanced scale, paused at rate 0, no tour.
//
// `advance()` is one host step: while playing the date moves by the rate (`SimClock.advance`) and stops at a range end
// with the reason; then a running, unpaused tour counts the step and, at the end of its stop, selects the next stop's
// body or ends after the last.
//
// Written as JSON with sorted keys: `{"dayOffset", "pitchDegrees", "playing", "rateIndex", "scaleMode", "schema": 4,
// "selection", "stopReason", "tourIndex", "tourPaused", "tourStep", "tourStop", "yawSteps", "zoomSteps"}`.
// `decode(_:)` reads the schema first and refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or malformed key of its schema;
// - `newer-version`: a schema above 4 (whatever else the payload holds);
// - `out-of-range`: a selection outside 0…8, a date outside the model's range, a pitch off its grid or outside 5…85,
//   zoom steps outside −1…12, a scale mode other than 0 or 1, a rate outside 0…3, an unknown stop reason, or a tour,
//   stop or step outside the bundled tours.
// A schema-3 document migrates paused at rate 0 with no tour; a schema-2 document also with the enhanced scale mode; a
// schema-1 document (`{"schema": 1, "selection": <index>}`) also with J2000.0 and the overview camera. A refusal changes
// nothing; the caller opens `SolarState.initial`.
//
// `select(_:)` accepts a whole index 0…8; `next()` and `previous()` step by one and refuse a step past an end (next at
// Neptune, previous at the Sun). `stepDate(by:)` accepts ±1, ±30 and ±365 days within the range; `setDate(_:)` any day in
// the range ("Now"). `orbit(_:)` turns the yaw by ±1 step; `tilt(_:)` and `zoom(_:)` move by ±1 step within their
// ranges; `resetView()` restores the overview camera and keeps the selection, the date and the scale mode;
// `setScaleMode(_:)` switches the mode; `setPlaying(_:)`, `setRate(_:)`, `startTour(_:)`, `nextTourStop()`,
// `pauseTour(_:)`, `stopTour()` and `apply(_:)` (a saved view) drive the clock and the tour. Each returns false or a
// refusal, with nothing changed, when refused.
import Foundation

/// Why a saved Solar System Explorer state was refused.
public enum SolarStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``SolarState/schemaVersion``).
    case newerVersion = "newer-version"
    /// A value outside its range (selection, date, pitch or zoom).
    case outOfRange = "out-of-range"
}

/// The state of a Solar System Explorer session: the selected body, the simulated date and the camera.
public struct SolarState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes (it also reads schema 1 and migrates it).
    public static let schemaVersion = 4
    /// The catalog the selection refers to.
    public static let catalog = BodyCatalog.bundled
    /// The number of selectable bodies (9).
    public static let bodyCount = BodyCatalog.bundled.bodies.count
    /// The overview pitch, degrees.
    public static let overviewPitch = 35
    /// The pitch range, degrees (values on the grid 5 + 10k).
    public static let pitchRange = 5...85
    /// The degrees per tilt step.
    public static let pitchStep = 10
    /// The degrees per yaw step.
    public static let yawStepDegrees = 15.0
    /// The zoom-step range (distance 60 × 1.25^−n).
    public static let zoomRange = -1...12
    /// The camera distance at zoom step 0, scene units.
    public static let overviewDistance = 60.0
    /// The distance factor per zoom step.
    public static let zoomFactor = 1.25
    /// The Sun selected at J2000.0 with the overview camera.
    public static let initial = SolarState(selection: 0)

    /// The selected (focused) body index, 0…8.
    public private(set) var selection: Int
    /// The simulated date, days since J2000.0, within ``SimulatedDate/range``.
    public private(set) var dayOffset: Double
    /// The camera yaw in whole 15° steps (unbounded; 24 steps make a full turn).
    public private(set) var yawSteps: Int
    /// The camera pitch in degrees, 5…85 on the grid 5 + 10k.
    public private(set) var pitchDegrees: Int
    /// The zoom steps, −1…12.
    public private(set) var zoomSteps: Int
    /// The scale mode (A14-P03).
    public private(set) var scaleMode: ScaleMode
    /// Whether simulated time runs (A14-P04).
    public private(set) var playing: Bool = false
    /// The rate, an index into `SimClock.rates` (0…3).
    public private(set) var rateIndex: Int = 0
    /// Why motion last stopped by itself: "" or `SimClock.endOfRange`.
    public private(set) var stopReason: String = ""
    /// The running tour, an index into `Tour.bundled`, or −1 for none.
    public private(set) var tourIndex: Int = -1
    /// The current stop of the running tour.
    public private(set) var tourStop: Int = 0
    /// The steps spent at the current stop (0 ..< its hold).
    public private(set) var tourStep: Int = 0
    /// Whether the running tour holds.
    public private(set) var tourPaused: Bool = false

    /// The state with body `selection` (clamped into 0…8) selected at J2000.0 with the overview camera.
    public init(selection: Int) {
        self.selection = min(max(selection, 0), Self.bodyCount - 1)
        self.dayOffset = 0
        self.yawSteps = 0
        self.pitchDegrees = Self.overviewPitch
        self.zoomSteps = 0
        self.scaleMode = .enhanced
    }

    /// The state from all of its values, or nil when one is outside its range (see the file header).
    public init?(selection: Int, dayOffset: Double, yawSteps: Int, pitchDegrees: Int, zoomSteps: Int,
                 scaleMode: ScaleMode = .enhanced) {
        guard Self.valid(selection: selection, dayOffset: dayOffset, pitchDegrees: pitchDegrees,
                         zoomSteps: zoomSteps) else { return nil }
        self.selection = selection
        self.dayOffset = dayOffset
        self.yawSteps = yawSteps
        self.pitchDegrees = pitchDegrees
        self.zoomSteps = zoomSteps
        self.scaleMode = scaleMode
    }

    /// True when every value lies in its range.
    static func valid(selection: Int, dayOffset: Double, pitchDegrees: Int, zoomSteps: Int) -> Bool {
        (0..<bodyCount).contains(selection) && dayOffset.isFinite && SimulatedDate.range.contains(dayOffset)
            && pitchRange.contains(pitchDegrees) && (pitchDegrees - pitchRange.lowerBound) % pitchStep == 0
            && zoomRange.contains(zoomSteps)
    }

    /// True when the clock and tour values are valid together.
    static func validClockAndTour(rateIndex: Int, stopReason: String, tourIndex: Int, tourStop: Int,
                                  tourStep: Int) -> Bool {
        guard (0..<SimClock.rates.count).contains(rateIndex), stopReason.isEmpty || stopReason == SimClock.endOfRange
        else { return false }
        if tourIndex == -1 { return tourStop == 0 && tourStep == 0 }
        guard Tour.bundled.indices.contains(tourIndex) else { return false }
        let stops = Tour.bundled[tourIndex].stops
        guard stops.indices.contains(tourStop) else { return false }
        return (0..<stops[tourStop].holdSteps).contains(tourStep)
    }

    /// The running tour, or nil.
    public var tour: Tour? { Tour.bundled.indices.contains(tourIndex) ? Tour.bundled[tourIndex] : nil }

    /// The caption of the current tour stop, or nil without a tour.
    public var tourCaption: String? {
        guard let tour, tour.stops.indices.contains(tourStop) else { return nil }
        return tour.stops[tourStop].caption
    }

    /// The selected body.
    public var body: CelestialBody { Self.catalog.bodies[selection] }

    /// The selected body's fact card.
    public var factCard: FactCard {
        Self.catalog.factCard(for: selection) ?? FactCard(bodyID: body.id, name: body.name, kind: body.kind, facts: [])
    }

    /// The simulated date.
    public var date: SimulatedDate { SimulatedDate(dayOffset: dayOffset) ?? .j2000 }

    /// The camera yaw in degrees, `yawSteps × 15` reduced to [0, 360).
    public var yawDegrees: Double {
        let degrees = (Double(yawSteps) * Self.yawStepDegrees).truncatingRemainder(dividingBy: 360)
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// The camera distance, 60 × 1.25^−zoomSteps scene units.
    public var cameraDistance: Double { Self.overviewDistance * pow(Self.zoomFactor, -Double(zoomSteps)) }

    /// Selects body `index`; false, with nothing changed, for an index outside 0…8.
    @discardableResult
    public mutating func select(_ index: Int) -> Bool {
        guard (0..<Self.bodyCount).contains(index) else { return false }
        selection = index
        return true
    }

    /// Selects the next body; false, with nothing changed, at the last body (Neptune).
    @discardableResult
    public mutating func next() -> Bool { select(selection + 1) }

    /// Selects the previous body; false, with nothing changed, at the first body (the Sun).
    @discardableResult
    public mutating func previous() -> Bool { select(selection - 1) }

    /// Steps the date by `days`; the refusal, with nothing changed, for a step other than ±1, ±30, ±365 or one
    /// leaving the range.
    @discardableResult
    public mutating func stepDate(by days: Int) -> DateStepRefusal? {
        switch date.stepped(by: days) {
        case .success(let next):
            dayOffset = next.dayOffset
            return nil
        case .failure(let refusal):
            return refusal
        }
    }

    /// Turns the yaw by `direction` (−1 or +1) steps; false for another value.
    @discardableResult
    public mutating func orbit(_ direction: Int) -> Bool {
        guard direction == 1 || direction == -1 else { return false }
        yawSteps += direction
        return true
    }

    /// Tilts by `direction` (−1 or +1) × 10°; false, with nothing changed, for another value or beyond 5…85.
    @discardableResult
    public mutating func tilt(_ direction: Int) -> Bool {
        guard direction == 1 || direction == -1 else { return false }
        let next = pitchDegrees + direction * Self.pitchStep
        guard Self.pitchRange.contains(next) else { return false }
        pitchDegrees = next
        return true
    }

    /// Zooms by `direction` (+1 closer, −1 farther); false, with nothing changed, for another value or beyond −1…12.
    @discardableResult
    public mutating func zoom(_ direction: Int) -> Bool {
        guard direction == 1 || direction == -1 else { return false }
        let next = zoomSteps + direction
        guard Self.zoomRange.contains(next) else { return false }
        zoomSteps = next
        return true
    }

    /// Switches to scale mode `mode`.
    public mutating func setScaleMode(_ mode: ScaleMode) {
        scaleMode = mode
    }

    /// Plays (`true`) or pauses simulated time; playing clears the stop reason.
    public mutating func setPlaying(_ on: Bool) {
        playing = on
        if on { stopReason = "" }
    }

    /// Chooses rate `index`; false, with nothing changed, outside 0…3.
    @discardableResult
    public mutating func setRate(_ index: Int) -> Bool {
        guard (0..<SimClock.rates.count).contains(index) else { return false }
        rateIndex = index
        return true
    }

    /// Sets the date to `days` since J2000.0 ("Now"); false, with nothing changed, for a non-finite day or one
    /// outside the range.
    @discardableResult
    public mutating func setDate(_ days: Double) -> Bool {
        guard days.isFinite, SimulatedDate.range.contains(days) else { return false }
        dayOffset = days
        stopReason = ""
        return true
    }

    /// Starts tour `index` at its first stop (selecting its body), restarting a running tour; false outside the
    /// bundled tours.
    @discardableResult
    public mutating func startTour(_ index: Int) -> Bool {
        guard Tour.bundled.indices.contains(index), let first = Tour.bundled[index].stops.first else { return false }
        tourIndex = index
        tourStop = 0
        tourStep = 0
        tourPaused = false
        selection = first.bodyIndex
        return true
    }

    /// Moves the running tour to its next stop (selecting its body) or ends it after the last; false without a tour.
    @discardableResult
    public mutating func nextTourStop() -> Bool {
        guard let tour else { return false }
        if tourStop + 1 < tour.stops.count {
            tourStop += 1
            tourStep = 0
            selection = tour.stops[tourStop].bodyIndex
        } else {
            stopTour()
        }
        return true
    }

    /// Holds (`true`) or resumes the running tour; false without a tour.
    @discardableResult
    public mutating func pauseTour(_ on: Bool) -> Bool {
        guard tour != nil else { return false }
        tourPaused = on
        return true
    }

    /// Ends the running tour (the selection stays).
    public mutating func stopTour() {
        tourIndex = -1
        tourStop = 0
        tourStep = 0
        tourPaused = false
    }

    /// One host step (see the file header).
    public mutating func advance() {
        if playing {
            let next = SimClock.advance(dayOffset: dayOffset, rateIndex: rateIndex)
            dayOffset = next.dayOffset
            if next.stopped {
                playing = false
                stopReason = SimClock.endOfRange
            }
        }
        if let tour, !tourPaused, tour.stops.indices.contains(tourStop) {
            tourStep += 1
            if tourStep >= tour.stops[tourStop].holdSteps { nextTourStop() }
        }
    }

    /// Applies a saved view: the body, date, rate, camera and scale mode; the tour ends and time pauses.
    public mutating func apply(_ view: SavedView) {
        selection = view.selection
        dayOffset = view.dayOffset
        rateIndex = view.rateIndex
        yawSteps = view.yawSteps
        pitchDegrees = view.pitchDegrees
        zoomSteps = view.zoomSteps
        scaleMode = ScaleMode(rawValue: view.scaleMode) ?? .enhanced
        playing = false
        stopReason = ""
        stopTour()
    }

    /// The current view as a saved view document.
    public var savedView: SavedView? {
        SavedView(selection: selection, dayOffset: dayOffset, rateIndex: rateIndex, yawSteps: yawSteps,
                  pitchDegrees: pitchDegrees, zoomSteps: zoomSteps, scaleMode: scaleMode.rawValue)
    }

    /// Restores the overview camera (yaw 0, pitch 35°, zoom 0); the selection and the date stay.
    public mutating func resetView() {
        yawSteps = 0
        pitchDegrees = Self.overviewPitch
        zoomSteps = 0
    }

    private enum CodingKeys: String, CodingKey {
        case schema, selection, dayOffset, yawSteps, pitchDegrees, zoomSteps, scaleMode
        case playing, rateIndex, stopReason, tourIndex, tourStop, tourStep, tourPaused
    }

    /// Decodes a schema-3 state or migrates a schema-2 or schema-1 state; throws for another schema, a malformed key or a value
    /// outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        let selection = try c.decode(Int.self, forKey: .selection)
        if schema == 1 {
            guard (0..<Self.bodyCount).contains(selection) else {
                throw DecodingError.dataCorruptedError(forKey: .selection, in: c, debugDescription: "not a valid state")
            }
            self.init(selection: selection)
            return
        }
        let mode: ScaleMode? = schema == 2 ? .enhanced
            : ScaleMode(rawValue: try c.decode(Int.self, forKey: .scaleMode))
        guard (2...Self.schemaVersion).contains(schema), let mode,
              let state = SolarState(selection: selection, dayOffset: try c.decode(Double.self, forKey: .dayOffset),
                                     yawSteps: try c.decode(Int.self, forKey: .yawSteps),
                                     pitchDegrees: try c.decode(Int.self, forKey: .pitchDegrees),
                                     zoomSteps: try c.decode(Int.self, forKey: .zoomSteps), scaleMode: mode) else {
            throw DecodingError.dataCorruptedError(forKey: .selection, in: c, debugDescription: "not a valid state")
        }
        var decoded = state
        if schema == 4 {
            let playing = try c.decode(Bool.self, forKey: .playing)
            let rate = try c.decode(Int.self, forKey: .rateIndex)
            let reason = try c.decode(String.self, forKey: .stopReason)
            let tour = try c.decode(Int.self, forKey: .tourIndex)
            let stop = try c.decode(Int.self, forKey: .tourStop)
            let step = try c.decode(Int.self, forKey: .tourStep)
            let paused = try c.decode(Bool.self, forKey: .tourPaused)
            guard Self.validClockAndTour(rateIndex: rate, stopReason: reason, tourIndex: tour, tourStop: stop,
                                         tourStep: step) else {
                throw DecodingError.dataCorruptedError(forKey: .rateIndex, in: c, debugDescription: "not a valid state")
            }
            decoded.playing = playing; decoded.rateIndex = rate; decoded.stopReason = reason
            decoded.tourIndex = tour; decoded.tourStop = stop; decoded.tourStep = step; decoded.tourPaused = paused
        }
        self = decoded
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
        try c.encode(dayOffset, forKey: .dayOffset)
        try c.encode(yawSteps, forKey: .yawSteps)
        try c.encode(pitchDegrees, forKey: .pitchDegrees)
        try c.encode(zoomSteps, forKey: .zoomSteps)
        try c.encode(scaleMode.rawValue, forKey: .scaleMode)
        try c.encode(playing, forKey: .playing)
        try c.encode(rateIndex, forKey: .rateIndex)
        try c.encode(stopReason, forKey: .stopReason)
        try c.encode(tourIndex, forKey: .tourIndex)
        try c.encode(tourStop, forKey: .tourStop)
        try c.encode(tourStep, forKey: .tourStep)
        try c.encode(tourPaused, forKey: .tourPaused)
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<SolarState, SolarStateRefusal> {
        struct Header: Decodable { var schema: Int }
        struct PayloadV1: Decodable { var selection: Int }
        struct PayloadV2: Decodable {
            var selection: Int; var dayOffset: Double; var yawSteps: Int; var pitchDegrees: Int; var zoomSteps: Int
        }
        struct PayloadV3: Decodable { var scaleMode: Int }
        struct PayloadV4: Decodable {
            var playing: Bool; var rateIndex: Int; var stopReason: String; var tourIndex: Int; var tourStop: Int
            var tourStep: Int; var tourPaused: Bool
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        if header.schema == 1 {
            guard let payload = try? decoder.decode(PayloadV1.self, from: data) else { return .failure(.damaged) }
            guard (0..<bodyCount).contains(payload.selection) else { return .failure(.outOfRange) }
            return .success(SolarState(selection: payload.selection))
        }
        guard let p = try? decoder.decode(PayloadV2.self, from: data) else { return .failure(.damaged) }
        var mode = ScaleMode.enhanced
        if header.schema >= 3 {
            guard let v3 = try? decoder.decode(PayloadV3.self, from: data) else { return .failure(.damaged) }
            guard let decoded = ScaleMode(rawValue: v3.scaleMode) else { return .failure(.outOfRange) }
            mode = decoded
        }
        guard var state = SolarState(selection: p.selection, dayOffset: p.dayOffset, yawSteps: p.yawSteps,
                                     pitchDegrees: p.pitchDegrees, zoomSteps: p.zoomSteps, scaleMode: mode) else {
            return .failure(.outOfRange)
        }
        if header.schema == 4 {
            guard let v4 = try? decoder.decode(PayloadV4.self, from: data) else { return .failure(.damaged) }
            guard validClockAndTour(rateIndex: v4.rateIndex, stopReason: v4.stopReason, tourIndex: v4.tourIndex,
                                    tourStop: v4.tourStop, tourStep: v4.tourStep) else {
                return .failure(.outOfRange)
            }
            state.playing = v4.playing; state.rateIndex = v4.rateIndex; state.stopReason = v4.stopReason
            state.tourIndex = v4.tourIndex; state.tourStop = v4.tourStop; state.tourStep = v4.tourStep
            state.tourPaused = v4.tourPaused
        }
        return .success(state)
    }
}
