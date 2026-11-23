// BackwardsAuroraFreezePreview — feature 394 (R02-G10-04) T-R02G1004-004 (FR-R02G1004-002; SC-R02G1004-003;
// clarification Q3). The timeline freeze preview: the exact diagnostic a band press held 0.5 s, or a swipe while it
// lasts, shows — the wave as it would be after reversing the chosen section [start, end], computed with the kernel's own
// reversal (`BackwardsAuroraWave.reversed(start:end:)`) on a copy of the play's wave, with the interior positions whose
// would-be bend exceeds the bend limit L (kinks), the lowest seam of the reversal whose would-be bend exceeds the
// breaking limit B (the tear, judged exactly as the kernel judges it over `BackwardsAuroraWave.seams`), the checkpoints
// the would-be wave matches and the line "would match 3 of 4 checkpoints, worst bend 9 of 12" or "would tear at seam
// 5". The preview is computed for any section in range, also on a finished play and for a section the kernel would
// refuse (a palindrome, a length outside the level's sections): it is presentation only, the play is never changed, so
// the digest is unchanged. Integers only; no clock, no random source.
import Foundation

/// The would-be wave of reversing the chosen section (feature 394): samples, kinks, tear and matched checkpoints.
public struct BackwardsAuroraFreezePreview: Sendable, Equatable {
    /// The section's first position.
    public let start: Int
    /// The section's last position (after `start`).
    public let end: Int
    /// The would-be samples: the kernel's reversal of [start, end] of the play's wave.
    public let samples: [Int]
    /// The interior positions whose would-be bend exceeds the bend limit L, ascending.
    public let kinks: [Int]
    /// The lowest seam position of the reversal whose would-be bend exceeds the breaking limit B, or nil (no tear).
    public let tear: Int?
    /// The checkpoints the would-be wave matches (at the target's height).
    public let matched: Int
    /// The level's checkpoint count (the "of" of the matched count in ``text``).
    public let checkpointCount: Int
    /// The level's bend limit L (the "of" of the worst bend in ``text``).
    public let bendLimit: Int

    /// The preview of reversing [`start`, `end`] of `play`'s wave, or nil when the section is out of range (start < 0,
    /// end ≥ N or start ≥ end). The play is not changed.
    public static func make(play: BackwardsAuroraPlay, start: Int, end: Int) -> BackwardsAuroraFreezePreview? {
        let wave: BackwardsAuroraWave = play.wave
        guard start >= 0, start < end, end < wave.count else { return nil }
        let level: BackwardsAuroraLevel = play.level
        let after: BackwardsAuroraWave = wave.reversed(start: start, end: end)
        var kinks: [Int] = []
        for k in after.interior where abs(after.bend(at: k)) > level.bendLimit {
            kinks.append(k)
        }
        var tear: Int?
        for seam in BackwardsAuroraWave.seams(start: start, end: end, count: after.count)
        where abs(after.bend(at: seam)) > level.breakingLimit {
            tear = seam
            break
        }
        var matched: Int = 0
        for hit in level.matched(after) where hit {
            matched += 1
        }
        return BackwardsAuroraFreezePreview(start: start, end: end, samples: after.samples, kinks: kinks, tear: tear,
                                            matched: matched, checkpointCount: level.checkpoints.count,
                                            bendLimit: level.bendLimit)
    }

    /// The largest would-be bend magnitude over the interior positions.
    public var worstBend: Int {
        var worst: Int = 0
        var k: Int = 1
        while k + 1 < samples.count {
            worst = max(worst, abs(samples[k - 1] - 2 * samples[k] + samples[k + 1]))
            k += 1
        }
        return worst
    }

    /// The preview in words: "would tear at seam 5" when the reversal would tear, otherwise "would match 3 of 4
    /// checkpoints, worst bend 9 of 12".
    public var text: String {
        if let tear { return "would tear at seam \(tear)" }
        return "would match \(matched) of \(checkpointCount) checkpoints, worst bend \(worstBend) of \(bendLimit)"
    }
}
