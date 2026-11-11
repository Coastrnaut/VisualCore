// TourPlayer.swift — plays a curated tour by feeding time into VisualCore's TourTimeline (feature 029 T-A03-409;
// FR-A03-406; US3). It holds no timers: the explorer calls `tick(now:)` from its frame loop and applies the returned
// framing through the model, so the precision clamp still applies. Captions are announced once per stop.
import FractalExplorerCore
import Observation
import SwiftUI
import VisualCoreMath

@MainActor
@Observable
final class TourPlayer {
    /// The tour being played, or nil.
    private(set) var tour: FractalTour?
    /// The caption of the stop reached last (kept after the tour finishes, until the next interaction).
    private(set) var caption: String?
    /// True while the tour moves or holds; false once finished or stopped.
    private(set) var isPlaying = false
    /// Captions announced to VoiceOver (tests).
    private(set) var announcements: [String] = []

    private var timeline: TourTimeline?
    private var startTime = 0.0
    private var announcedStop = -1

    /// Starts `tour` at `now` from the current framing.
    func start(_ tour: FractalTour, from framing: PlaneFraming, now: Double, reduceMotion: Bool) {
        self.tour = tour
        timeline = tour.timeline(from: framing, reduceMotion: reduceMotion)
        startTime = now
        caption = nil
        announcedStop = -1
        isPlaying = true
    }

    /// The tour's state at `now`; nil when not playing. Reaching a stop sets and announces its caption once.
    func tick(now: Double) -> TourTimeline.State? {
        guard isPlaying, let tour, let timeline else { return nil }
        let state = timeline.state(at: now - startTime)
        if state.phase != .flying, state.stopIndex != announcedStop {
            announcedStop = state.stopIndex
            let text = tour.stops[state.stopIndex].caption
            caption = text
            announcements.append(text)
            AccessibilityNotification.Announcement(text).post()
        }
        if state.phase == .finished { isPlaying = false }
        return state
    }

    /// Stops the tour where it is (the view stays).
    func stop() {
        isPlaying = false
        timeline = nil
    }

    /// Clears the caption and the tour (a later interaction after the tour).
    func clear() {
        stop()
        tour = nil
        caption = nil
    }
}
