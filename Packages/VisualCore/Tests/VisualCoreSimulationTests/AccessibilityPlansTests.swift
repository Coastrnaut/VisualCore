// AccessibilityPlansTests — feature 226 R02-F26 T-R02F26-008 and T-R02F26-012 (FR-R02F26-020, FR-R02F26-021,
// FR-R02F26-030, FR-R02F26-040, FR-R02F26-050; research R2, R3).
import Foundation
import Testing
@testable import VisualCoreSimulation

private func announce(_ text: String, _ time: Double, _ kind: AnnouncementKind = .outcome) -> Announcement {
    Announcement(text: text, kind: kind, time: time)
}

// MARK: - Announcements (5 sequences)

@Test func announcementSpacedPostsAllPass() {
    var planner = AnnouncementPlanner()
    var posted: [String] = []
    for (index, time) in [0.0, 0.5, 1.2, 2.0].enumerated() {
        if let a = planner.submit(announce("a\(index)", time)) { posted.append(a.text) }
    }
    #expect(posted == ["a0", "a1", "a2", "a3"])
    #expect(planner.flush(now: 5) == nil)
}

@Test func announcementBurstMergesToNewestAfterFlush() {
    var planner = AnnouncementPlanner()
    #expect(planner.submit(announce("first", 0)) == announce("first", 0))
    #expect(planner.submit(announce("second", 0.1)) == nil)
    #expect(planner.submit(announce("third", 0.2)) == nil)
    #expect(planner.submit(announce("newest", 0.3)) == nil)
    #expect(planner.flush(now: 0.6) == announce("newest", 0.3))
    #expect(planner.flush(now: 2) == nil)
    // The flushed post at 0.6 starts a new interval.
    #expect(planner.submit(announce("next", 0.9)) == nil)
    #expect(planner.flush(now: 1.1) == announce("next", 0.9))
}

@Test func announcementDisabledPostsNothingAndDropsPending() {
    var planner = AnnouncementPlanner()
    #expect(planner.submit(announce("first", 0)) != nil)
    #expect(planner.submit(announce("held", 0.1)) == nil)
    planner.enabled = false
    #expect(planner.submit(announce("off", 1)) == nil)
    #expect(planner.flush(now: 2) == nil)
    planner.enabled = true
    #expect(planner.flush(now: 3) == nil)
    #expect(planner.submit(announce("back", 4)) == announce("back", 4))
}

@Test func announcementFlushBeforeIntervalIsNil() {
    var planner = AnnouncementPlanner(minimumInterval: 0.5)
    #expect(planner.submit(announce("first", 10)) != nil)
    #expect(planner.submit(announce("held", 10.2)) == nil)
    #expect(planner.flush(now: 10.3) == nil)
    #expect(planner.flush(now: 10.49) == nil)
    #expect(planner.flush(now: 10.5) == announce("held", 10.2))
}

@Test func announcementKindsKept() {
    var planner = AnnouncementPlanner()
    let kinds: [AnnouncementKind] = [.rejection, .outcome, .level, .state]
    var seen: [AnnouncementKind] = []
    for (index, kind) in kinds.enumerated() {
        if let a = planner.submit(announce("k\(index)", Double(index), kind)) { seen.append(a.kind) }
    }
    #expect(seen == kinds)
    #expect(planner.submit(announce("held", 3.1, .rejection)) == nil)
    #expect(planner.flush(now: 4)?.kind == .rejection)
}

// MARK: - Haptics (5 sequences)

@Test func hapticSpacedEventsAllPlay() {
    var planner = HapticPlanner()
    let played = [0.0, 0.05, 0.2, 1.0].compactMap { planner.submit(HapticEvent(kind: .selection, time: $0)) }
    #expect(played.map(\.time) == [0.0, 0.05, 0.2, 1.0])
}

@Test func hapticBurstDropsExtras() {
    var planner = HapticPlanner(minimumInterval: 0.05)
    let times = [0.0, 0.01, 0.02, 0.04, 0.06, 0.07]
    let played = times.compactMap { planner.submit(HapticEvent(kind: .impactLight, time: $0)) }
    #expect(played.map(\.time) == [0.0, 0.06])
}

@Test func hapticDisabledPlaysNothing() {
    var planner = HapticPlanner()
    planner.enabled = false
    let played = [0.0, 1.0, 2.0].compactMap { planner.submit(HapticEvent(kind: .success, time: $0)) }
    #expect(played.isEmpty)
}

@Test func hapticReenablePlays() {
    var planner = HapticPlanner()
    #expect(planner.submit(HapticEvent(kind: .warning, time: 0)) != nil)
    planner.enabled = false
    #expect(planner.submit(HapticEvent(kind: .warning, time: 1)) == nil)
    planner.enabled = true
    #expect(planner.submit(HapticEvent(kind: .warning, time: 1.01)) == HapticEvent(kind: .warning, time: 1.01))
}

@Test func hapticKindsPreserved() {
    var planner = HapticPlanner()
    let kinds: [HapticKind] = [.selection, .success, .warning, .error, .impactLight, .impactMedium, .impactHeavy]
    let played = kinds.enumerated().compactMap { planner.submit(HapticEvent(kind: $0.element, time: Double($0.offset))) }
    #expect(played.map(\.kind) == kinds)
}

// MARK: - State signs

@Test func stateSignMissingSign() {
    let signs = [StateSign(id: "on", colorHex: "#00FF00", sign: "●"), StateSign(id: "off", colorHex: "#FF0000", sign: "  "),
                 StateSign(id: "idle", colorHex: "#888888", sign: "")]
    #expect(stateSignProblems(signs) == ["idle: no sign", "off: no sign"])
}

@Test func stateSignDuplicateSign() {
    let signs = [StateSign(id: "b", colorHex: "#00FF00", sign: "+"), StateSign(id: "a", colorHex: "#FF0000", sign: "+"),
                 StateSign(id: "c", colorHex: "#0000FF", sign: "-")]
    #expect(stateSignProblems(signs) == ["+: used by a, b"])
}

@Test func stateSignValidPalette() {
    let signs = [StateSign(id: "alive", colorHex: "#FFFFFF", sign: "■"), StateSign(id: "dead", colorHex: "#000000", sign: "□"),
                 StateSign(id: "born", colorHex: "#00FF00", sign: "+")]
    #expect(stateSignProblems(signs).isEmpty)
    #expect(stateSignProblems([]).isEmpty)
}

// MARK: - Reduce Motion transitions (FR-R02F26-050)

@Test func transitionDurationFollowsReduceMotion() {
    #expect(transitionDuration(0.3, reduceMotion: true) == 0)
    #expect(transitionDuration(0.3, reduceMotion: false) == 0.3)
    #expect(transitionDuration(0, reduceMotion: false) == 0)
    #expect(transitionDuration(-1, reduceMotion: false) == 0)
    #expect(transitionDuration(.nan, reduceMotion: false) == 0)
    #expect(transitionDuration(.infinity, reduceMotion: false) == 0)
    #expect(transitionDuration(.infinity, reduceMotion: true) == 0)
}
