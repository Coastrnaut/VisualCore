// AuroraControls — feature 153 (A21-P02) T-A21-203, T-A21-206 (FR-A21-201, FR-A21-205; clarification Q4;
// contracts/experience.md "Chrome"); feature 154 (A21-P03) T-A21-305, T-A21-306 (FR-A21-304–306; clarification Q5). The native controls of Aurora. Every control reads the presenter's mirror, sends
// through the action port, has a spoken label and value from one list (`labels(_:)`, also read by the tests), a hint
// and the identifier `experience.a21.aurora.<name>` (`ExperienceActionPort.identifier`):
//
//   - `preset` segmented picker (Polar night, Violet veil, Dawn haze → `preset.select [0…2]`);
//   - sliders `hue` ("Colour shift", −180°…180° → `colour.hue [−0.5…0.5]`), `speed` (0…2 times → `motion.speed`),
//     `turbulence` (0…100 % → `motion.turbulence`), `clouds` (0…100 % → `sky.clouds`) and `limit` ("Brightness
//     limit", 20…72 % → `light.limit [0.2…0.72]`);
//   - steppers `ribbons` (1…4 → `sky.ribbons`) and `stars` (0…400 in steps of 20 → `sky.stars`);
//   - the sound choice (feature 154): a `sound` toggle ("Sound", On or Off) and a `volume` slider ("Volume",
//     0…100 %). They send no action: the presenter keeps them in the preferences only (`setSound(on:)`,
//     `setVolume(_:)`), so the snapshot, the digest and the scenario manifest do not change, and nothing plays;
//   - `message`: the line about the saved choices (they could not be read, or could not be saved), when there is one;
//   - `hide-controls` ("Hide controls"): the presenter hides the controls. While hidden only `show-controls` remains:
//     a short line "Controls hidden. Tap the sky to show them." with the accessibility action "Show controls", so a
//     VoiceOver user can always bring them back; a tap on the sky does the same (the presenter's pointer).
// Every value is clamped to its range before it is sent; integer controls send whole numbers.
import AuroraCore
import Foundation
import SwiftUI
import VisualCoreExperienceHost

/// One spoken label of a control: its identifier name, its title and its value.
struct AuroraControlLabel: Equatable, Sendable {
    /// The identifier name (`experience.a21.aurora.<name>`).
    var name: String
    /// The spoken title, for example "Sky".
    var title: String
    /// The spoken value, for example "Polar night".
    var value: String

    /// "<title>, <value>".
    var text: String { title + ", " + value }
}

/// The native controls of Aurora (see the file header).
struct AuroraControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: SkyMirror
    /// The presenter: hides and shows the controls.
    let presenter: AuroraPresenter

    /// The name of the accessibility action that shows hidden controls.
    static let showControlsAction = "Show controls"
    /// The line shown while the controls are hidden.
    static let hiddenText = "Controls hidden. Tap the sky to show them."
    /// The star stepper's step.
    static let starStep = 20

    /// The preset titles, by index of `SkyPresets.all`.
    static var presetTitles: [String] { SkyPresets.all.map(\.name) }

    /// The hue shift in degrees, for example "0°", "+36°" or "−90°".
    static func hueText(_ turns: Double) -> String {
        let degrees = Int((turns * 360).rounded())
        if degrees > 0 { return "+\(degrees)°" }
        if degrees < 0 { return "−\(-degrees)°" }
        return "0°"
    }

    /// The speed, for example "1.0 times".
    static func speedText(_ speed: Double) -> String { String(format: "%.1f times", speed) }

    /// A share as a whole percent, for example "60 %".
    static func percentText(_ share: Double) -> String { "\(Int((share * 100).rounded())) %" }

    /// The spoken label of every control shown for `mirror`, in display order: only `show-controls` while hidden.
    static func labels(_ mirror: SkyMirror) -> [AuroraControlLabel] {
        if mirror.controlsHidden {
            return [AuroraControlLabel(name: "show-controls", title: "Controls hidden", value: showControlsAction)]
        }
        let preset = presetTitles[min(max(mirror.preset, 0), presetTitles.count - 1)]
        return [
            AuroraControlLabel(name: "preset", title: "Sky", value: preset),
            AuroraControlLabel(name: "hue", title: "Colour shift", value: hueText(mirror.hue)),
            AuroraControlLabel(name: "speed", title: "Speed", value: speedText(mirror.speed)),
            AuroraControlLabel(name: "turbulence", title: "Turbulence", value: percentText(mirror.turbulence)),
            AuroraControlLabel(name: "ribbons", title: "Ribbons", value: String(mirror.ribbons)),
            AuroraControlLabel(name: "stars", title: "Stars", value: String(mirror.stars)),
            AuroraControlLabel(name: "clouds", title: "Clouds", value: percentText(mirror.clouds)),
            AuroraControlLabel(name: "limit", title: "Brightness limit", value: percentText(mirror.limit)),
            AuroraControlLabel(name: "sound", title: "Sound", value: mirror.soundOn ? "On" : "Off"),
            AuroraControlLabel(name: "volume", title: "Volume", value: percentText(mirror.volume)),
            AuroraControlLabel(name: "hide-controls", title: "Hide controls", value: "Controls shown"),
        ]
    }

    /// The control each identifier name sends (the sound, volume, hide and show controls send nothing).
    static let actionOfControl: [String: String] = [
        "preset": "preset.select", "hue": "colour.hue", "speed": "motion.speed", "turbulence": "motion.turbulence",
        "ribbons": "sky.ribbons", "stars": "sky.stars", "clouds": "sky.clouds", "limit": "light.limit",
    ]

    /// `value` clamped to `range`.
    static func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The controls.
    var body: some View {
        let spoken = Dictionary(Self.labels(mirror).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return Group {
            if mirror.controlsHidden {
                Text(verbatim: Self.hiddenText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: spoken["show-controls"]?.title ?? ""))
                    .accessibilityHint(Text(verbatim: "Tap the sky or use the action Show controls"))
                    .accessibilityAction(named: Text(verbatim: Self.showControlsAction)) { presenter.showControls() }
                    .accessibilityIdentifier(port.identifier("show-controls"))
            } else {
                shown(spoken)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The controls while shown.
    private func shown(_ spoken: [String: AuroraControlLabel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Aurora").font(.headline).accessibilityAddTraits(.isHeader)
            if let message = mirror.message {
                Text(verbatim: message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("message"))
            }
            Picker(selection: Binding(get: { mirror.preset },
                                      set: { next in
                                          guard next != mirror.preset else { return }
                                          port.send("preset.select", [Double(next)])
                                      })) {
                ForEach(Array(Self.presetTitles.enumerated()), id: \.offset) { index, title in
                    Text(verbatim: title).tag(index)
                }
            } label: {
                Text(verbatim: "Sky")
            }
            .pickerStyle(.segmented)
            .spoken(spoken["preset"])
            .accessibilityHint(Text(verbatim: "Chooses one of the three skies"))
            .accessibilityIdentifier(port.identifier("preset"))
            slider("hue", control: "colour.hue", value: mirror.hue, range: SkyCore.hueRange,
                   hint: "Turns every colour of the sky around the colour wheel", spoken)
            slider("speed", control: "motion.speed", value: mirror.speed, range: SkyScene.speedRange,
                   hint: "How fast the sky moves; Reduce Motion keeps it still", spoken)
            slider("turbulence", control: "motion.turbulence", value: mirror.turbulence,
                   range: SkyScene.turbulenceRange, hint: "How strongly the ribbons fold", spoken)
            stepper("ribbons", control: "sky.ribbons", value: mirror.ribbons, range: SkyScene.ribbonsRange, step: 1,
                    hint: "How many ribbons of light the sky shows", spoken)
            stepper("stars", control: "sky.stars", value: mirror.stars, range: SkyScene.starsRange,
                    step: Self.starStep, hint: "How many stars the sky shows", spoken)
            slider("clouds", control: "sky.clouds", value: mirror.clouds, range: SkyScene.cloudinessRange,
                   hint: "How much of the sky the clouds cover", spoken)
            slider("limit", control: "light.limit", value: mirror.limit, range: SkyCore.limitRange,
                   hint: "No part of the sky gets brighter than this", spoken)
            Toggle(isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) })) {
                Text(verbatim: spoken["sound"]?.title ?? "")
            }
            .spoken(spoken["sound"])
            .accessibilityHint(Text(verbatim: "Keeps whether the sky's sound is on; nothing plays in this version"))
            .accessibilityIdentifier(port.identifier("sound"))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: (spoken["volume"]?.title ?? "") + ": " + (spoken["volume"]?.value ?? ""))
                    .font(.footnote)
                    .accessibilityHidden(true)
                Slider(value: Binding(get: { mirror.volume },
                                      set: { presenter.setVolume(Self.clamped($0, SkyPreferences.volumeRange)) }),
                       in: SkyPreferences.volumeRange)
                    .spoken(spoken["volume"])
                    .accessibilityHint(Text(verbatim: "How loud the sky's sound is when it is on"))
                    .accessibilityIdentifier(port.identifier("volume"))
            }
            Button {
                presenter.hideControls()
            } label: {
                Text(verbatim: "Hide controls").frame(minHeight: 44)
            }
            .spoken(spoken["hide-controls"])
            .accessibilityHint(Text(verbatim: "Shows only the sky; tap the sky to bring the controls back"))
            .accessibilityIdentifier(port.identifier("hide-controls"))
        }
    }

    /// A titled slider over `range` sending `control` with the clamped value.
    private func slider(_ name: String, control: String, value: Double, range: ClosedRange<Double>, hint: String,
                        _ spoken: [String: AuroraControlLabel]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: (spoken[name]?.title ?? "") + ": " + (spoken[name]?.value ?? ""))
                .font(.footnote)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { value },
                                  set: { next in
                                      let sent = Self.clamped(next, range)
                                      guard sent != value else { return }
                                      port.send(control, [sent])
                                  }), in: range)
                .spoken(spoken[name])
                .accessibilityHint(Text(verbatim: hint))
                .accessibilityIdentifier(port.identifier(name))
        }
    }

    /// A titled stepper over `range` in steps of `step` sending `control` with the whole clamped value.
    private func stepper(_ name: String, control: String, value: Int, range: ClosedRange<Int>, step: Int, hint: String,
                         _ spoken: [String: AuroraControlLabel]) -> some View {
        Stepper {
            Text(verbatim: (spoken[name]?.title ?? "") + ": " + (spoken[name]?.value ?? ""))
        } onIncrement: {
            let next = min(value + step, range.upperBound)
            if next != value { port.send(control, [Double(next)]) }
        } onDecrement: {
            let next = max(value - step, range.lowerBound)
            if next != value { port.send(control, [Double(next)]) }
        }
        .spoken(spoken[name])
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}

extension View {
    /// Applies `label`'s title and value as the accessibility label and value.
    func spoken(_ label: AuroraControlLabel?) -> some View {
        accessibilityLabel(Text(verbatim: label?.title ?? ""))
            .accessibilityValue(Text(verbatim: label?.value ?? ""))
    }
}
