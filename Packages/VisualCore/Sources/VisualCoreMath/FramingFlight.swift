// FramingFlight.swift — smooth flights between plane framings on a log zoom scale, and a timeline of tour stops
// (feature 029 T-A03-402; gap G-TOUR; FR-A03-402; research R2–R3; spec 029 clarification 2). Used for guided tours
// and "fly to" navigation in any 2D plane app (fractals, simulation domains, shader canvases).
import Foundation

/// A flight from one framing to another. The span changes geometrically (constant rate on a log scale) with easing;
/// the center moves in proportion to the span change, c = c₁ + (c₀ − c₁)·(s − s₁)/(s₀ − s₁), which keeps the target's
/// offset within |c₁ − c₀|/s₀ of the view (so a target inside the starting view stays in view). Equal spans move the
/// center linearly. Overshooting curves (back, elastic, bounce) are replaced by `sine`, which keeps the span monotonic.
public struct FramingFlight: Sendable, Equatable {
    /// Where the flight starts.
    public let from: PlaneFraming
    /// Where it ends (returned exactly at t ≥ 1).
    public let to: PlaneFraming

    /// A flight between two framings.
    public init(from: PlaneFraming, to: PlaneFraming) {
        self.from = from
        self.to = to
    }

    /// The framing at progress `t` (clamped to [0, 1]; non-finite counts as 0), eased with `curve` in-out.
    public func framing(at t: Double, curve: EasingCurve = .sine) -> PlaneFraming {
        guard t.isFinite, t > 0 else { return from }
        if t >= 1 { return to }
        let safe: EasingCurve = [.back, .elastic, .bounce].contains(curve) ? .sine : curve
        let u = ease(t, safe)
        let s0 = from.span, s1 = to.span
        let span = exp(log(s0) + (log(s1) - log(s0)) * u)
        let c0 = from.center, c1 = to.center
        let center: Vec2
        if abs(s0 - s1) <= 1e-12 * max(s0, s1) {
            center = c0 + (c1 - c0) * u
        } else {
            center = c1 + (c0 - c1) * ((span - s1) / (s0 - s1))
        }
        return PlaneFraming(center: center, span: span)
    }

    /// The flights from `from` to `to`: one direct flight when the target lies inside the starting view
    /// (|c₁ − c₀| ≤ s₀/2), else two flights via the framing at the midpoint with span max(s₀, s₁, 2·|c₁ − c₀|), which
    /// shows both points.
    public static func route(from: PlaneFraming, to: PlaneFraming) -> [FramingFlight] {
        let d = from.center.distance(to: to.center)
        guard d > from.span / 2 else { return [FramingFlight(from: from, to: to)] }
        let mid = PlaneFraming(center: (from.center + to.center) / 2, span: max(from.span, to.span, 2 * d))
        return [FramingFlight(from: from, to: mid), FramingFlight(from: mid, to: to)]
    }
}

/// A guided tour: from a start framing, fly to each stop (routes per `FramingFlight.route`), then hold it. With
/// `reduceMotion` the flights take no time (the view jumps) and the holds stay.
public struct TourTimeline: Sendable, Equatable {
    /// One stop of the tour.
    public struct Stop: Sendable, Equatable {
        /// The framing shown at the stop.
        public let framing: PlaneFraming
        /// Seconds to hold the stop (negative or non-finite counts as 0).
        public let hold: Double

        /// Creates a stop.
        public init(framing: PlaneFraming, hold: Double) {
            self.framing = framing
            self.hold = hold.isFinite ? max(0, hold) : 0
        }
    }

    /// Where the tour is.
    public enum Phase: String, Sendable, Equatable {
        case flying, holding, finished
    }

    /// The tour at a moment.
    public struct State: Sendable, Equatable {
        /// The framing to show.
        public let framing: PlaneFraming
        /// The stop being approached or held (0-based); the last stop when finished.
        public let stopIndex: Int
        /// Flying, holding or finished.
        public let phase: Phase
    }

    /// The framing before the first flight.
    public let start: PlaneFraming
    /// The stops in order (at least one).
    public let stops: [Stop]
    /// Seconds per flight between stops (> 0; non-finite or non-positive becomes 1); 0 with `reduceMotion`.
    public let flightDuration: Double
    /// True to jump between stops.
    public let reduceMotion: Bool

    private struct Segment: Sendable, Equatable {
        let flights: [FramingFlight]
        let flight: Double
        let hold: Double
    }

    private let segments: [Segment]

    /// A tour; `stops` must not be empty (an empty list becomes one stop at `start`, held for 0 s).
    public init(start: PlaneFraming, stops: [Stop], flightDuration: Double, reduceMotion: Bool) {
        self.start = start
        self.stops = stops.isEmpty ? [Stop(framing: start, hold: 0)] : stops
        self.reduceMotion = reduceMotion
        let duration = flightDuration.isFinite && flightDuration > 0 ? flightDuration : 1
        self.flightDuration = reduceMotion ? 0 : duration
        var previous = start
        var built: [Segment] = []
        for stop in self.stops {
            built.append(Segment(flights: FramingFlight.route(from: previous, to: stop.framing),
                                 flight: reduceMotion ? 0 : duration, hold: stop.hold))
            previous = stop.framing
        }
        segments = built
    }

    /// Total seconds from the first flight to the end of the last hold.
    public var duration: Double { segments.reduce(0) { $0 + $1.flight + $1.hold } }

    /// The tour at `time` seconds after it started (negative counts as 0).
    public func state(at time: Double) -> State {
        var t = time.isFinite ? max(0, time) : 0
        for (index, segment) in segments.enumerated() {
            if t < segment.flight {
                let legs = segment.flights
                let progress = t / segment.flight * Double(legs.count)
                let leg = min(legs.count - 1, Int(progress))
                return State(framing: legs[leg].framing(at: progress - Double(leg)), stopIndex: index, phase: .flying)
            }
            t -= segment.flight
            if t < segment.hold {
                return State(framing: stops[index].framing, stopIndex: index, phase: .holding)
            }
            t -= segment.hold
        }
        return State(framing: stops[stops.count - 1].framing, stopIndex: stops.count - 1, phase: .finished)
    }
}
