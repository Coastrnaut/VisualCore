// Timeline.swift — tweens and timelines (feature 006 T-F510; FR-F505; research R5).
// State is a pure function of time, so pause, seek and reverse are exact and deterministic.
// `reduceMotion` (clarification 2026-11-10) makes tweens jump to their end values and disables repeats.
import VisualCoreMath

public struct Tween: Sendable, Equatable {
    public var from: Double
    public var to: Double
    /// Seconds per pass (≥ 0; zero jumps straight to the end value).
    public var duration: Double
    public var curve: EasingCurve
    public var mode: EasingMode
    /// Number of passes (≥ 1); nil repeats forever.
    public var repeatCount: Int?
    /// Every second pass runs backwards (ping-pong).
    public var autoreverses: Bool

    public init(from: Double, to: Double, duration: Double, curve: EasingCurve = .linear, mode: EasingMode = .inOut,
                repeatCount: Int? = 1, autoreverses: Bool = false) {
        self.from = from; self.to = to
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.curve = curve; self.mode = mode
        self.repeatCount = repeatCount.map { max(1, $0) }
        self.autoreverses = autoreverses
    }

    /// Total length in seconds, or nil when it repeats forever.
    public var totalDuration: Double? { repeatCount.map { Double($0) * duration } }

    /// Value after the last pass.
    public var finalValue: Double {
        guard let n = repeatCount else { return to }
        return autoreverses && n % 2 == 0 ? from : to
    }

    public func value(at t: Double) -> Double {
        guard duration > 0 else { return finalValue }
        let t = t.isFinite ? max(0, t) : 0
        if let total = totalDuration, t >= total { return finalValue }
        let pass = (t / duration).rounded(.down)
        var progress = (t - pass * duration) / duration
        if autoreverses && Int(pass) % 2 == 1 { progress = 1 - progress }
        return from + (to - from) * ease(progress, curve, mode)
    }

    /// The same tween with repeats disabled (Reduce Motion).
    var single: Tween { var t = self; t.repeatCount = 1; t.autoreverses = false; return t }
}

public enum TimelineEvent: Sendable, Equatable {
    /// A tween reached its end while playing forwards.
    case completed(String)
    /// A tween returned to its start while playing backwards.
    case returnedToStart(String)
    /// The whole timeline reached its end (forwards) or its start (backwards).
    case finished
}

public struct Timeline: Sendable {
    public struct Entry: Sendable, Equatable {
        public var name: String
        public var tween: Tween
        public var offset: Double
    }

    public private(set) var entries: [Entry] = []
    /// Playback position in seconds, within [0, duration].
    public private(set) var time = 0.0
    /// Playback speed; negative plays in reverse.
    public var rate = 1.0
    public var isPaused = false
    /// Jump tweens to their end values and ignore repeats.
    public var reduceMotion = false

    public init() {}

    /// Adds a tween starting `offset` seconds into the timeline (names should be unique).
    public mutating func add(_ tween: Tween, at offset: Double = 0, name: String) {
        entries.append(Entry(name: name, tween: tween, offset: offset.isFinite ? max(0, offset) : 0))
    }

    private func effective(_ e: Entry) -> Tween { reduceMotion ? e.tween.single : e.tween }
    private func end(_ e: Entry) -> Double { effective(e).totalDuration.map { e.offset + $0 } ?? .infinity }

    /// Length of the timeline; infinite when a tween repeats forever.
    public var duration: Double { entries.map(end).max() ?? 0 }
    public var isFinished: Bool { rate >= 0 ? time >= duration : time <= 0 }

    public func value(of name: String) -> Double? {
        guard let e = entries.first(where: { $0.name == name }) else { return nil }
        if reduceMotion { return effective(e).finalValue }
        return e.tween.value(at: time - e.offset)
    }

    /// Moves the playhead without events.
    public mutating func seek(to t: Double) {
        guard t.isFinite else { return }
        time = min(max(0, t), duration)
    }

    /// Advances by `dt` × `rate` (or straight to the end under Reduce Motion) and returns the events crossed.
    @discardableResult
    public mutating func advance(by dt: Double) -> [TimelineEvent] {
        guard !isPaused, dt.isFinite, dt > 0, rate.isFinite, rate != 0 else { return [] }
        let previous = time
        if reduceMotion { time = rate > 0 ? duration : 0 }
        else { time = min(max(0, time + dt * rate), duration) }
        var events: [TimelineEvent] = []
        if time > previous {
            for e in entries where previous < end(e) && end(e) <= time { events.append(.completed(e.name)) }
            if time >= duration && previous < duration { events.append(.finished) }
        } else if time < previous {
            for e in entries where previous > e.offset && e.offset >= time { events.append(.returnedToStart(e.name)) }
            if time <= 0 && previous > 0 { events.append(.finished) }
        }
        return events
    }
}
