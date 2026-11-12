// ExperienceHostView — feature 189 T-U03-009 (FR-U03-060 to FR-U03-063; research R6; contract
// specs/189-ua-f03-experience-host/contracts/session-api.md). The SwiftUI face of a session: the canvas with the
// experience's native controls while it runs, and the session's own views while it prepares, after a failure and
// after a message. Every text comes from `SessionStrings`; every control has a stable identifier.
import SwiftUI
import VisualCoreExperience
import VisualCoreRendering
import VisualCoreUI

// MARK: - Identifiers

/// The accessibility identifiers of the host view's own elements.
public enum SessionViewID {
    /// The canvas of a running or suspended experience.
    public static let canvas = "session.canvas"
    /// The progress indication shown while an experience prepares.
    public static let preparing = "session.preparing"
    /// The button that cancels a preparation.
    public static let cancel = "session.cancel"
    /// The container of the failure view.
    public static let failure = "session.failure"
    /// The button that opens the failed experience again.
    public static let retry = "session.retry"
    /// The button that leaves the failure view or the message view.
    public static let back = "session.back"
    /// The container of the message view.
    public static let message = "session.message"
}

// MARK: - Button style

/// The one style of the session's own buttons: a bordered, filled shape of at least 44 by 44 points whose pressed
/// state changes opacity and scale, so that it does not depend on color.
public struct SessionButtonStyle: ButtonStyle {
    /// The smallest width and height of a button, in points.
    public static let minimumSize: CGFloat = 44

    /// Creates the style.
    public init() {}

    /// The label with padding, the minimum size, a rounded system background and the pressed state.
    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: Self.minimumSize, minHeight: Self.minimumSize)
            .background(Color(uiColor: .secondarySystemBackground), in: shape)
            .overlay(shape.strokeBorder(Color(uiColor: .separator), lineWidth: 1))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// A full-width button of the session's views: its text wraps instead of being cut.
private struct SessionButton: View {
    let title: String
    let identifier: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SessionButtonStyle())
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(identifier)
    }
}

/// The spacing and padding the three state views share.
private enum SessionLayout {
    static let spacing: CGFloat = 16
    static let padding: CGFloat = 24
    /// The largest height of the controls below the canvas; taller controls scroll.
    static let controlsMaxHeight: CGFloat = 280
}

// MARK: - Preparing

/// Shown while an experience prepares: a progress indication and a Cancel button.
public struct SessionPreparingView: View {
    private let onCancel: @MainActor () -> Void

    /// Creates the view; `onCancel` runs when Cancel is pressed.
    public init(onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
    }

    /// The scrollable content.
    public var body: some View {
        ScrollView {
            VStack(spacing: SessionLayout.spacing) {
                ProgressView {
                    Text(SessionStrings.text(.preparing))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(SessionViewID.preparing)
                SessionButton(title: SessionStrings.text(.cancel), identifier: SessionViewID.cancel, action: onCancel)
            }
            .frame(maxWidth: .infinity)
            .padding(SessionLayout.padding)
        }
    }
}

// MARK: - Failure

/// Shown after a failure: a symbol with the title, what went wrong, the stable code, Retry and Back.
public struct SessionFailureView: View {
    private let title: String
    private let detail: String
    private let code: String
    private let onRetry: @MainActor () -> Void
    private let onBack: @MainActor () -> Void

    /// Creates the view with the title, the failure's message `detail` and its `code`; `onRetry` and `onBack` run
    /// when the buttons are pressed.
    public init(title: String, detail: String, code: String,
                onRetry: @escaping @MainActor () -> Void, onBack: @escaping @MainActor () -> Void) {
        self.title = title
        self.detail = detail
        self.code = code
        self.onRetry = onRetry
        self.onBack = onBack
    }

    /// The scrollable content.
    public var body: some View {
        ScrollView {
            VStack(spacing: SessionLayout.spacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                SessionButton(title: SessionStrings.text(.retry), identifier: SessionViewID.retry, action: onRetry)
                SessionButton(title: SessionStrings.text(.back), identifier: SessionViewID.back, action: onBack)
            }
            .frame(maxWidth: .infinity)
            .padding(SessionLayout.padding)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(SessionViewID.failure)
        }
    }
}

// MARK: - Message

/// Shown after the session closed an experience by itself: the reason and Back.
public struct SessionMessageView: View {
    private let text: String
    private let onBack: @MainActor () -> Void

    /// Creates the view with the message `text`; `onBack` runs when Back is pressed.
    public init(text: String, onBack: @escaping @MainActor () -> Void) {
        self.text = text
        self.onBack = onBack
    }

    /// The scrollable content.
    public var body: some View {
        ScrollView {
            VStack(spacing: SessionLayout.spacing) {
                Image(systemName: "info.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                SessionButton(title: SessionStrings.text(.back), identifier: SessionViewID.back, action: onBack)
            }
            .frame(maxWidth: .infinity)
            .padding(SessionLayout.padding)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(SessionViewID.message)
        }
    }
}

// MARK: - Host view

/// Shows a session: the canvas and the experience's controls while it runs or is suspended, and the session's own
/// views while it prepares, after a failure and after a message. It forwards the scene phase to the session.
public struct ExperienceHostView: View {
    private let session: ExperienceSession
    private let onRetry: (@MainActor () async -> Void)?
    @Environment(\.scenePhase) private var scenePhase

    /// Creates the view of `session`. The session stays owned by the caller.
    ///
    /// `onRetry` replaces what the failure view's Retry does. Without it the session opens its last request
    /// again (`ExperienceSession.retry()`), with the snapshot that request carried. An opener that stores
    /// snapshots passes an action that opens the experience with the state stored now (feature 191).
    public init(session: ExperienceSession, onRetry: (@MainActor () async -> Void)? = nil) {
        self.session = session
        self.onRetry = onRetry
    }

    /// The view of the session's current state.
    public var body: some View {
        content
            .onAppear { session.setScenePhase(Self.input(for: scenePhase)) }
            .onChange(of: scenePhase) { _, phase in session.setScenePhase(Self.input(for: phase)) }
    }

    @ViewBuilder private var content: some View {
        switch session.state {
        case .running, .suspended:
            running
        case .preparing:
            SessionPreparingView { session.close() }
        case .failed:
            SessionFailureView(title: SessionStrings.text(.failureTitle),
                               detail: session.failure?.failure.message ?? "",
                               code: session.failure?.failure.code ?? "",
                               onRetry: {
                                   Task {
                                       if let onRetry { await onRetry() } else { await session.retry() }
                                   }
                               },
                               onBack: { session.back() })
        case .message:
            SessionMessageView(text: session.message ?? SessionStrings.text(.memoryMessage)) { session.back() }
        case .idle, .closing:
            Color.clear
        }
    }

    @ViewBuilder private var running: some View {
        VStack(spacing: 0) {
            if let host = session.renderHost {
                RenderSurface(host: host, accessibilityLabel: canvasLabel,
                              accessibilityHint: SessionStrings.text(.canvasHint))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(SessionViewID.canvas)
            }
            if let experience = session.experience {
                ScrollView {
                    experience.controls
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .frame(maxHeight: SessionLayout.controlsMaxHeight)
            }
        }
    }

    /// The experience's state in words, or its id while there is no state.
    private var canvasLabel: String {
        guard let experience = session.experience else { return "" }
        // Reading the port's revision makes the label follow every accepted action.
        _ = experience.port.revision
        let summary = experience.accessibilitySummary
        return summary.isEmpty ? experience.id.rawValue : summary
    }

    /// The session's input for a SwiftUI scene phase; an unknown phase counts as inactive.
    static func input(for phase: ScenePhase) -> ScenePhaseInput {
        switch phase {
        case .active: .active
        case .inactive: .inactive
        case .background: .background
        @unknown default: .inactive
        }
    }
}
