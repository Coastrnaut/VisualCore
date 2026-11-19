// TimerProbe — feature 175 (A24-P03) T-A24-306 (clarification Q3; data-model.md "TimerProbe"). Decides from the
// renderer's extension list whether GPU frame times can be measured: `supported` when `GL_EXT_disjoint_timer_query`
// is listed, otherwise `unsupported` with a reason. The presenter creates a GPU frame timer only on `supported`.
// Pure Foundation; no GPU call.
import Foundation

/// Whether the renderer offers a GPU frame timer.
public enum TimerSupport: Equatable, Sendable, Codable {
    /// The timer extension is offered; GPU frame times may be measured.
    case supported
    /// The timer extension is not offered (or a test forced it off), with the reason shown to the person.
    case unsupported(reason: String)
}

/// The GPU timer probe: a pure decision over the renderer's extension list.
public enum TimerProbe {
    /// The OpenGL ES extension that provides GPU time-elapsed queries.
    public static let extensionName = "GL_EXT_disjoint_timer_query"
    /// The reason given when the extension is not listed.
    public static let unsupportedReason = "GL_EXT_disjoint_timer_query is not offered by this renderer"

    /// ``TimerSupport/supported`` when `extensions` lists ``extensionName`` exactly, otherwise
    /// ``TimerSupport/unsupported(reason:)`` with ``unsupportedReason``.
    public static func decide(extensions: [String]) -> TimerSupport {
        extensions.contains(extensionName) ? .supported : .unsupported(reason: unsupportedReason)
    }
}
