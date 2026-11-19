// DroppedFrameRule — feature 175 (A24-P03) T-A24-306 (clarification Q4; data-model.md "DroppedFrameRule"). A frame is
// dropped when its interval exceeds 1.5 × the presenter's frame period (1,000 / 60 ms), so strictly more than 25 ms;
// its interval still counts in the summary. A frame without an interval (the first) is never dropped.
import Foundation

/// The dropped-frame rule: interval > ``factor`` × ``periodMs``.
public enum DroppedFrameRule {
    /// The presenter's frame period in milliseconds (60 frames per second).
    public static let periodMs: Double = 1000.0 / 60.0
    /// The multiple of the period above which a frame is dropped.
    public static let factor: Double = 1.5
    /// The threshold in milliseconds, ``factor`` × ``periodMs`` (25 ms).
    public static var thresholdMs: Double { periodMs * factor }

    /// True when `intervalMs` is strictly greater than ``thresholdMs``; false for nil (a frame without an interval).
    public static func isDropped(intervalMs: Double?) -> Bool {
        guard let intervalMs else { return false }
        return intervalMs > thresholdMs
    }
}
