// FractalTours.swift — the curated guided tours: well-known places of the Mandelbrot set with short factual captions
// (feature 029 T-A03-408; FR-A03-406; US3; research R7). The flights between stops are VisualCore's FramingFlight
// and TourTimeline; this file holds only the content.
import Foundation
import VisualCoreMath

/// One stop of a tour.
public struct TourStop: Sendable, Equatable {
    /// The framing shown at the stop.
    public let framing: PlaneFraming
    /// The caption (at most 120 characters).
    public let caption: String
}

/// A curated tour of the Mandelbrot set.
public struct FractalTour: Sendable, Equatable, Identifiable {
    /// Stable identifier ("seahorse", "elephant", "mini").
    public let id: String
    /// Display name.
    public let name: String
    /// One-line summary for the list.
    public let summary: String
    /// The stops in order.
    public let stops: [TourStop]
    /// Tours visit Mandelbrot places.
    public var mode: FractalMode { .mandelbrot }

    /// Seconds per flight between stops.
    public static let flightSeconds = 4.0
    /// Seconds each stop is held.
    public static let holdSeconds = 3.0
    /// The longest caption.
    public static let maxCaptionLength = 120

    /// The VisualCore timeline from `start`.
    public func timeline(from start: PlaneFraming, reduceMotion: Bool) -> TourTimeline {
        TourTimeline(start: start,
                     stops: stops.map { TourTimeline.Stop(framing: $0.framing, hold: Self.holdSeconds) },
                     flightDuration: Self.flightSeconds, reduceMotion: reduceMotion)
    }
}

/// The three curated tours.
public enum FractalTours {
    private static func stop(_ x: Double, _ y: Double, _ span: Double, _ caption: String) -> TourStop {
        TourStop(framing: PlaneFraming(center: Vec2(x, y), span: span), caption: caption)
    }

    /// Seahorse Valley, Elephant Valley and a mini Mandelbrot on the main antenna.
    public static let all: [FractalTour] = [
        FractalTour(id: "seahorse", name: "Seahorse Valley",
                    summary: "Spirals between the main body and the large disc on its left.",
                    stops: [
                        stop(-0.75, 0.1, 0.5, "Seahorse Valley lies in the narrow gap between the main cardioid and the period-2 disc."),
                        stop(-0.7445, 0.1315, 0.05, "Closer in, the boundary curls into double spirals that look like seahorse tails."),
                        stop(-0.743643887, 0.131825904, 0.005, "Every spiral holds smaller spirals; the pattern repeats as far as precision allows."),
                    ]),
        FractalTour(id: "elephant", name: "Elephant Valley",
                    summary: "Trunk-like spirals in the gap on the right side of the main body.",
                    stops: [
                        stop(0.3, 0.02, 0.4, "Elephant Valley is the gap on the right of the main cardioid, near the point 0.25."),
                        stop(0.282, 0.0105, 0.05, "The bulbs along the edge stretch into curled shapes like elephant trunks."),
                        stop(0.2815, 0.0102, 0.006, "Each trunk is lined with smaller bulbs, each with its own tiny trunks."),
                    ]),
        FractalTour(id: "mini", name: "Mini Mandelbrot",
                    summary: "A small copy of the whole set on the antenna to the left.",
                    stops: [
                        stop(-1.5, 0, 1.2, "The thin antenna on the left runs along the real axis toward −2."),
                        stop(-1.755, 0, 0.1, "Bright points on the antenna hint at small copies of the set hidden there."),
                        stop(-1.75488, 0, 0.04, "A mini Mandelbrot near −1.755: a complete small copy of the whole set."),
                    ]),
    ]

    /// The tour with `id`.
    public static func tour(_ id: String) -> FractalTour? { all.first { $0.id == id } }
}
