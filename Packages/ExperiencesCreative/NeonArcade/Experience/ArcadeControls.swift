// ArcadeControls — feature 075 (A10-P01) T-A10-104 (FR-A10-121, FR-A10-122). The native controls of Neon Arcade in
// one section:
//   Steer left and Steer right (`run.left`, `run.right`): held down they send `run.steer [−1]` / `[1]` once when the
//   press begins and `run.steer [0]` when it ends; with VoiceOver, activating one sends its full steering, which holds
//   until Straight or the other direction;
//   Straight (`run.straight` → `run.steer [0]`);
//   the pause toggle (`run.pause` → `run.pause [1/0]`, "Pause");
//   Restart (`run.restart`, a new run);
//   and the status line (`run.status`: score, lives, playing, paused or over).
// Feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-321): Start on the title screen, Play again on the game-over
// screen (`run.start`); the pause toggle only while playing or paused and Restart only while paused or over (the other
// screens refuse them); the Sound and Haptics toggles (`settings.sound`, `settings.haptics` → [1/0]) on every screen.
// The status line names the screen (title screen, playing, paused, over).
// Every control has an accessible label and value (or hint) and an identifier from the port; hit areas are at least
// 44 points high and text wraps.
import SwiftUI
import NeonArcadeCore
import VisualCoreExperienceHost

/// The controls of Neon Arcade.
struct ArcadeControls: View {
    let port: ExperienceActionPort
    let mirror: ArcadeMirror

    /// The spoken steering value: "Left", "Right", "Straight", or "Left 50 percent" for a partial value.
    static func steeringWords(_ value: Double) -> String {
        guard value.isFinite, abs(value) > 1e-9 else { return "Straight" }
        let side = value < 0 ? "Left" : "Right"
        let percent = Int((abs(value) * 100).rounded())
        return percent >= 100 ? side : "\(side) \(percent) percent"
    }

    /// The label of the start button: "Start" on the title screen, "Play again" on the game-over screen, nil on the
    /// screens without one.
    static func startTitle(_ screen: ArcadeScreen) -> String? {
        switch screen {
        case .title: return "Start"
        case .over: return "Play again"
        case .playing, .paused: return nil
        }
    }

    /// "On" or "Off".
    static func onOff(_ on: Bool) -> String { on ? "On" : "Off" }

    /// Whether the pause toggle applies on `screen` (playing or paused).
    static func canPause(_ screen: ArcadeScreen) -> Bool { screen == .playing || screen == .paused }

    /// Whether Restart applies on `screen` (paused or over).
    static func canRestart(_ screen: ArcadeScreen) -> Bool { screen == .paused || screen == .over }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Neon Dodge").font(.headline).accessibilityAddTraits(.isHeader)
            if let title = Self.startTitle(mirror.screen) {
                Button {
                    _ = port.send("run.start")
                } label: {
                    Text(verbatim: title).font(.body).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: mirror.screen == .over ? "Run over" : "Title screen"))
                .accessibilityHint(Text(verbatim: mirror.screen == .over ? "Starts a new run in wave 1"
                                                                          : "Starts the game"))
                .accessibilityIdentifier(port.identifier("run.start"))
            }
            HStack(spacing: 8) {
                ArcadeHoldButton(title: "Steer left", identifier: port.identifier("run.left"), value: -1,
                                 steering: mirror.steering, port: port)
                ArcadeHoldButton(title: "Steer right", identifier: port.identifier("run.right"), value: 1,
                                 steering: mirror.steering, port: port)
            }
            Button {
                _ = port.send("run.steer", [0])
            } label: {
                Text(verbatim: "Straight").font(.body).frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Straight"))
            .accessibilityValue(Text(verbatim: Self.steeringWords(mirror.steering)))
            .accessibilityHint(Text(verbatim: "Stops steering"))
            .accessibilityIdentifier(port.identifier("run.straight"))
            Toggle(isOn: Binding(get: { mirror.paused },
                                 set: { on in if on != mirror.paused { _ = port.send("run.pause", [on ? 1 : 0]) } })) {
                Text(verbatim: "Pause").font(.body)
            }
            .frame(minHeight: 44)
            .disabled(!Self.canPause(mirror.screen))
            .accessibilityLabel(Text(verbatim: "Pause"))
            .accessibilityValue(Text(verbatim: mirror.paused ? "Paused" : "Playing"))
            .accessibilityHint(Text(verbatim: "Stops and resumes the falling objects and the player"))
            .accessibilityIdentifier(port.identifier("run.pause"))
            Button {
                _ = port.send("run.restart")
            } label: {
                Text(verbatim: "Restart").font(.body).frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(!Self.canRestart(mirror.screen))
            .accessibilityLabel(Text(verbatim: "Restart"))
            .accessibilityValue(Text(verbatim: mirror.over ? "Run over" : "Run in progress"))
            .accessibilityHint(Text(verbatim: "Starts a new run with score 0 and three lives"))
            .accessibilityIdentifier(port.identifier("run.restart"))
            Toggle(isOn: Binding(get: { mirror.sound },
                                 set: { on in
                                     if on != mirror.sound { _ = port.send("settings.sound", [on ? 1 : 0]) }
                                 })) {
                Text(verbatim: "Sound").font(.body)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Sound"))
            .accessibilityValue(Text(verbatim: Self.onOff(mirror.sound)))
            .accessibilityHint(Text(verbatim: "Plays the game's sound effects"))
            .accessibilityIdentifier(port.identifier("settings.sound"))
            Toggle(isOn: Binding(get: { mirror.haptics },
                                 set: { on in
                                     if on != mirror.haptics { _ = port.send("settings.haptics", [on ? 1 : 0]) }
                                 })) {
                Text(verbatim: "Haptics").font(.body)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Haptics"))
            .accessibilityValue(Text(verbatim: Self.onOff(mirror.haptics)))
            .accessibilityHint(Text(verbatim: "Plays taps for pickups, hits and new waves"))
            .accessibilityIdentifier(port.identifier("settings.haptics"))
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("run.status"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A button that steers while it is held: the press sends `run.steer [value]` once, the release `run.steer [0]`.
/// With VoiceOver, activating it sends `run.steer [value]`.
struct ArcadeHoldButton: View {
    let title: String
    let identifier: String
    /// The steering value sent while held (−1 or 1).
    let value: Double
    /// The current steering value (for the accessible value).
    let steering: Double
    let port: ExperienceActionPort
    @State private var pressed = false

    var body: some View {
        Text(verbatim: title)
            .font(.body)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(pressed ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.15)))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    _ = port.send("run.steer", [value])
                }
                .onEnded { _ in
                    pressed = false
                    _ = port.send("run.steer", [0])
                })
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: pressed || steering == value ? "Steering" : "Not steering"))
            .accessibilityHint(Text(verbatim: "Hold to steer; release to go straight"))
            .accessibilityAction { _ = port.send("run.steer", [value]) }
            .accessibilityIdentifier(identifier)
    }
}
