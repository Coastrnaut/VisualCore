// PlaybackState.swift — play/pause intent, background suspension and the Reduce Motion start rule for animated scenes
// (feature 033 A04-P01 T-A04-115; spec edge cases "background" and "Reduce Motion"; checklist CHK017). Pure value type
// so every app's lifecycle rule is the same and host-testable.

/// Whether an animated scene should advance: the person's play/pause choice, suspended while the app is in the
/// background. Returning to the foreground resumes only if the person had it playing; under Reduce Motion a scene
/// starts paused.
public struct PlaybackState: Sendable, Equatable {
    /// The person's choice: play (true) or pause (false).
    public private(set) var wantsToPlay: Bool
    /// Whether the app is in the background.
    public private(set) var isInBackground = false

    /// Whether the scene should advance now.
    public var isRunning: Bool { wantsToPlay && !isInBackground }

    /// A scene that plays at start when `autoplay` is true, unless `reduceMotion` is on (then it starts paused).
    public init(reduceMotion: Bool, autoplay: Bool = true) { wantsToPlay = autoplay && !reduceMotion }

    /// The person presses Play.
    public mutating func play() { wantsToPlay = true }
    /// The person presses Pause.
    public mutating func pause() { wantsToPlay = false }
    /// Play if paused, pause if playing.
    public mutating func toggle() { wantsToPlay.toggle() }
    /// The app goes to the background: the scene stops, the person's choice is kept.
    public mutating func enterBackground() { isInBackground = true }
    /// The app returns: the scene runs again only if the person had chosen to play.
    public mutating func enterForeground() { isInBackground = false }
}
