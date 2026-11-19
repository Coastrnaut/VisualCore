// GBLExplanation — feature 177 (A24-P05) T-A24-505 (FR-A24-504; clarification "What does 'About these numbers' say,
// and where is it?"; User Story 3; contracts/review.md "Experience"; gap G-EXPLAIN). The copy of "About these numbers",
// the in-app explanation of what Graphics Benchmark Lab measures and of its limits, in exactly the five sections of the
// clarification, in this order:
//
//   1. "What is measured": the frame interval, the presenter CPU time and the GPU time where a timer exists.
//   2. "Valid, qualified, invalid": what each class means and what makes a run qualified or invalid.
//   3. "Why numbers differ": thermal state, Low Power Mode, display refresh, background work, the case's version.
//   4. "Simulator numbers": they say nothing about a device.
//   5. "What the lab does not do": rank devices, claim precision, send results.
//
// The literals are scanned with `scripts/check_copy_claims.py` and the shared denylist
// (`Configs/copy-claims-denylist.json`): no number followed by a unit, never the denylist's frame or refresh phrases
// (the copy says "display refresh" and "a gap of over a second"), no quality word, no feature the lab does not have,
// and no ranking, precision or scientific claim. Plain text; ``ExplanationView`` shows it with spoken headings.

/// One section of the explanation: a spoken heading and its plain text.
struct GBLExplanationSection: Equatable, Identifiable, Sendable {
    /// The heading, read by VoiceOver as a header.
    let title: String
    /// The section's plain text.
    let text: String

    /// The section's identity: its title (the titles are distinct).
    var id: String { title }
}

/// The copy of "About these numbers" (see the file header).
enum GBLExplanation {
    /// The explanation's own heading.
    static let title = "About these numbers"

    /// The five sections of clarification Q5, in order.
    static let sections: [GBLExplanationSection] = [
        GBLExplanationSection(
            title: "What is measured",
            text: "For every frame of the measurement phase the lab keeps three times. The frame interval is the "
                + "time from one drawn frame to the next. The presenter CPU time is how long the presenter takes to "
                + "submit the frame's drawing work. The GPU time is how long the graphics processor works on the "
                + "frame; it is kept only where the device offers a GPU timer, and otherwise the result says that "
                + "GPU time is not available. Warm-up and cool-down frames are left out. A result gives p50, p95 "
                + "and p99 of these times and the frame counts."),
        GBLExplanationSection(
            title: "Valid, qualified, invalid",
            text: "A valid run completed under ordinary conditions. A qualified run completed, but something calls "
                + "for care: the thermal state changed or the device was hot, Low Power Mode was on, some frames "
                + "were dropped, there were too few frames for p99, or no device report was kept. An invalid run "
                + "is not a measurement: it was stopped before the end, it was interrupted (for example by leaving "
                + "the app, by the app going to the background, or by a gap of over a second between frames), or "
                + "no frame was measured. Each result lists its reasons."),
        GBLExplanationSection(
            title: "Why numbers differ",
            text: "The same case can give other numbers from one run to the next and from one device to another. "
                + "The thermal state of the device changes how much work it does. Low Power Mode lowers the work "
                + "the device allows. The display refresh of the device sets how often a frame can be shown. "
                + "Background work of the system and of other apps takes time from the lab. A new case version "
                + "draws other work, so results of another case version are not compared. Trials are compared "
                + "only when the case and its version, the device model, the OS version, the app build and the "
                + "quality tier are the same, and none of them is invalid."),
        GBLExplanationSection(
            title: "Simulator numbers",
            text: "Numbers measured in the simulator come from the computer that runs the simulator, not from a "
                + "device. They say nothing about any device and are never device results."),
        GBLExplanationSection(
            title: "What the lab does not do",
            text: "The lab does not rank devices and gives no score. It does not claim precision beyond what it "
                + "kept, and it does not compare its numbers with other tools. It never sends results anywhere: a "
                + "result leaves the device only when you export it yourself."),
    ]

    /// The section titles, in order.
    static var titles: [String] {
        var result: [String] = []
        for section in sections { result.append(section.title) }
        return result
    }

    /// The whole explanation as one text: the heading, then each section's title and text, joined by new lines.
    static var fullText: String {
        var lines = [title]
        for section in sections {
            lines.append(section.title)
            lines.append(section.text)
        }
        return lines.joined(separator: "\n")
    }
}
