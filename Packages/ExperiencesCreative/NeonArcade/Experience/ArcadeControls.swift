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
// Feature 078 (A10-P04) T-A10-403 (FR-A10-401, FR-A10-402, FR-A10-413, FR-A10-421; clarification 1): the Steering
// sensitivity stepper (`settings.sensitivity` → [0…4]; value "Step 3 of 5, normal"), the best-score text
// (`scores.best`: "Best score: none" or "Best score: 1,230 in wave 4", on every screen) and, when the table could not
// be read or saved, the problem text (`scores.problem`). The labels, values and hints of every control come from one
// table, ``ArcadeControls/accessibility(_:)``, so tests can check that each is labelled. Every text uses a text style
// (headline, body, footnote) and wraps, so it grows with Dynamic Type.
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

    /// The words of the sensitivity steps 0…4, gentle to sharp.
    static let sensitivityWords = ["gentle", "soft", "normal", "quick", "sharp"]

    /// The spoken sensitivity: "Step 3 of 5, normal" (a step outside 0…4 is clamped first).
    static func sensitivityValue(_ step: Int) -> String {
        let step = Sensitivity.clampedStep(step)
        return "Step \(step + 1) of \(Sensitivity.reaches.count), \(sensitivityWords[step])"
    }

    /// The accessible label, value and hint of a control.
    struct Accessibility: Equatable {
        let label: String
        let value: String
        let hint: String
    }

    /// The accessible label, value and hint of every control by name (the names of `port.identifier`), as shown for
    /// `mirror`: every native action and the texts.
    @MainActor
    static func accessibility(_ mirror: ArcadeMirror) -> [String: Accessibility] {
        let start = startTitle(mirror.screen) ?? "Start"
        return [
            "run.start": Accessibility(label: start, value: mirror.screen == .over ? "Run over" : "Title screen",
                                       hint: mirror.screen == .over ? "Starts a new run in wave 1"
                                                                    : "Starts the game"),
            "run.left": Accessibility(label: "Steer left", value: mirror.steering == -1 ? "Steering" : "Not steering",
                                      hint: "Hold to steer; release to go straight"),
            "run.right": Accessibility(label: "Steer right", value: mirror.steering == 1 ? "Steering" : "Not steering",
                                       hint: "Hold to steer; release to go straight"),
            "run.straight": Accessibility(label: "Straight", value: steeringWords(mirror.steering),
                                          hint: "Stops steering"),
            "run.pause": Accessibility(label: "Pause", value: mirror.paused ? "Paused" : "Playing",
                                       hint: "Stops and resumes the falling objects and the player"),
            "run.restart": Accessibility(label: "Restart", value: mirror.over ? "Run over" : "Run in progress",
                                         hint: "Starts a new run with score 0 and three lives"),
            "settings.sound": Accessibility(label: "Sound", value: onOff(mirror.sound),
                                            hint: "Plays the game's sound effects"),
            "settings.haptics": Accessibility(label: "Haptics", value: onOff(mirror.haptics),
                                              hint: "Plays taps for pickups, hits and new waves"),
            "settings.sensitivity": Accessibility(label: "Steering sensitivity",
                                                  value: sensitivityValue(mirror.sensitivity),
                                                  hint: "How far a drag on the field must reach for full steering"),
            "scores.best": Accessibility(label: mirror.best, value: "", hint: "The best score kept on this device"),
            "run.status": Accessibility(label: sentence(mirror.status), value: "", hint: ""),
        ]
    }

    /// The control names whose action is in `actions`: `run.steer` is reached by Steer left, Steer right and
    /// Straight; every other action by the control of its own name.
    static func controlNames(for action: String) -> [String] {
        action == "run.steer" ? ["run.left", "run.right", "run.straight"] : [action]
    }

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
        let table = Self.accessibility(mirror)
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Neon Dodge").font(.headline).accessibilityAddTraits(.isHeader)
            if let title = Self.startTitle(mirror.screen) {
                Button {
                    _ = port.send("run.start")
                } label: {
                    Text(verbatim: title).font(.body).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .labelled(table["run.start"])
                .accessibilityIdentifier(port.identifier("run.start"))
            }
            HStack(spacing: 8) {
                ArcadeHoldButton(title: table["run.left"]?.label ?? "Steer left",
                                 identifier: port.identifier("run.left"), value: -1, steering: mirror.steering,
                                 hint: table["run.left"]?.hint ?? "", port: port)
                ArcadeHoldButton(title: table["run.right"]?.label ?? "Steer right",
                                 identifier: port.identifier("run.right"), value: 1, steering: mirror.steering,
                                 hint: table["run.right"]?.hint ?? "", port: port)
            }
            Button {
                _ = port.send("run.steer", [0])
            } label: {
                Text(verbatim: "Straight").font(.body).frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .labelled(table["run.straight"])
            .accessibilityIdentifier(port.identifier("run.straight"))
            Toggle(isOn: Binding(get: { mirror.paused },
                                 set: { on in if on != mirror.paused { _ = port.send("run.pause", [on ? 1 : 0]) } })) {
                Text(verbatim: "Pause").font(.body)
            }
            .frame(minHeight: 44)
            .disabled(!Self.canPause(mirror.screen))
            .labelled(table["run.pause"])
            .accessibilityIdentifier(port.identifier("run.pause"))
            Button {
                _ = port.send("run.restart")
            } label: {
                Text(verbatim: "Restart").font(.body).frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(!Self.canRestart(mirror.screen))
            .labelled(table["run.restart"])
            .accessibilityIdentifier(port.identifier("run.restart"))
            Toggle(isOn: Binding(get: { mirror.sound },
                                 set: { on in
                                     if on != mirror.sound { _ = port.send("settings.sound", [on ? 1 : 0]) }
                                 })) {
                Text(verbatim: "Sound").font(.body)
            }
            .frame(minHeight: 44)
            .labelled(table["settings.sound"])
            .accessibilityIdentifier(port.identifier("settings.sound"))
            Toggle(isOn: Binding(get: { mirror.haptics },
                                 set: { on in
                                     if on != mirror.haptics { _ = port.send("settings.haptics", [on ? 1 : 0]) }
                                 })) {
                Text(verbatim: "Haptics").font(.body)
            }
            .frame(minHeight: 44)
            .labelled(table["settings.haptics"])
            .accessibilityIdentifier(port.identifier("settings.haptics"))
            Stepper(value: Binding(get: { mirror.sensitivity },
                                   set: { step in
                                       let step = Sensitivity.clampedStep(step)
                                       if step != mirror.sensitivity {
                                           _ = port.send("settings.sensitivity", [Double(step)])
                                       }
                                   }),
                    in: Sensitivity.steps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Steering sensitivity").font(.body)
                    Text(verbatim: Self.sensitivityValue(mirror.sensitivity))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            .labelled(table["settings.sensitivity"])
            .accessibilityIdentifier(port.identifier("settings.sensitivity"))
            Text(verbatim: mirror.best)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .labelled(table["scores.best"])
                .accessibilityIdentifier(port.identifier("scores.best"))
            if let problem = mirror.scoresProblem {
                Text(verbatim: problem)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("scores.problem"))
            }
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
    /// The accessible hint.
    let hint: String
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
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityAction { _ = port.send("run.steer", [value]) }
            .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// The accessible label, value (when not empty) and hint (when not empty) of `entry` (feature 078).
    func labelled(_ entry: ArcadeControls.Accessibility?) -> some View {
        accessibilityLabel(Text(verbatim: entry?.label ?? ""))
            .accessibilityValue(Text(verbatim: entry?.value ?? ""))
            .accessibilityHint(Text(verbatim: entry?.hint ?? ""))
    }
}
