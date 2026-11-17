// WallpaperControls — feature 139 (A19-P02) T-A19-207, T-A19-209 (FR-A19-204, FR-A19-205, FR-A19-206; clarification
// Q5). The native controls of Living Wallpapers, modelled on Ambient Clock's: every control reads the presenter's
// mirror, sends through the action port only when its value changes, and has an accessible label, value and hint and
// the identifier `experience.a19.living-wallpapers.<name>` (`ExperienceActionPort.identifier`):
//
//   - `scene` menu (the four scene names → `scene.select [0…3]`) and `preset` menu (the scene's three preset names →
//     `scene.preset [0…2]`);
//   - one slider per scene parameter, `parameter-0` … `parameter-2`, over that parameter's range
//     (→ `scene.parameter [index, value]`);
//   - `template` menu (the nine device names → `canvas.template [0…8]`) and `orientation` menu (Portrait, Landscape →
//     `canvas.orientation [0 / 1]`);
//   - `time` slider, the animation moment 0…3600 s (→ `scene.time [seconds]`);
//   - `format` menu (PNG, JPEG, HEIC → `export.format [0…2]`);
//   - `motion` toggle (→ `motion.enabled [0 / 1]`);
//   - `export` button: runs the presenter's `StillExport` with the environment's timed still renderer
//     (`experienceStillRenderer`) and shows the result ("Exported 1206 by 2622 pixels, PNG, 512 kB.") or the reason
//     of the refusal or failure in `export-message`. Without a renderer (no experience open) it says so.
import LivingWallpapersCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The native controls of Living Wallpapers (see the file header).
struct WallpaperControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: WallpaperMirror
    /// The presenter that runs the export.
    let presenter: WallpaperPresenter
    /// The open experience's still renderer; nil when no experience is open.
    @Environment(\.experienceStillRenderer) private var stillRenderer
    /// The sentence of the last export.
    @State private var exportMessage: String?

    /// The orientation titles, by index.
    static let orientationTitles = ["Portrait", "Landscape"]
    /// The format titles, by index of `ExportFormat.allCases`.
    static let formatTitles = ["PNG", "JPEG", "HEIC"]
    /// The sentence shown when no experience is open to render.
    static let noRendererSentence = "No picture is open to export."

    /// The animation time in words: "Moment 12.5 seconds".
    static func timeWords(_ seconds: Double) -> String {
        "Moment " + String(format: "%.1f", seconds) + " seconds"
    }

    /// The sentence of an export's outcome: the output's size, format and kilobytes, or the reason (with the
    /// planner's sentence for a refusal).
    @MainActor
    static func sentence(_ output: StillExport.Output?, export: StillExport) -> String {
        if let output {
            let kilobytes = max(1, (output.result.bytes + 512) / 1024)
            let format = formatTitles[ExportFormat.allCases.firstIndex(of: output.plan.format) ?? 0]
            return "Exported \(output.result.width) by \(output.result.height) pixels, \(format), \(kilobytes) kB."
        }
        switch export.state {
        case .cancelled:
            return "The export was cancelled."
        case .failed(let reason):
            return export.lastRefusal?.sentence ?? reason.sentence
        default:
            return "The export did not finish."
        }
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Living Wallpapers").font(.headline).accessibilityAddTraits(.isHeader)
            scenePicker
            presetPicker
            parameterSliders
            menu("Device", name: "template", titles: CanvasTemplates.all.map(\.device), current: mirror.template,
                 hint: "Chooses the device whose screen size is exported") { index in
                port.send("canvas.template", [Double(index)])
            }
            menu("Orientation", name: "orientation", titles: Self.orientationTitles, current: mirror.orientation,
                 hint: "Chooses portrait or landscape") { index in
                port.send("canvas.orientation", [Double(index)])
            }
            timeSlider
            menu("Format", name: "format", titles: Self.formatTitles, current: mirror.format,
                 hint: "Chooses the file format of the exported still") { index in
                port.send("export.format", [Double(index)])
            }
            motionToggle
            exportButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The scene menu (sends `scene.select` when the choice changes).
    private var scenePicker: some View {
        menu("Scene", name: "scene", titles: SceneCatalog.scenes.map(\.name), current: mirror.scene,
             hint: "Chooses the procedural scene") { index in
            port.send("scene.select", [Double(index)])
        }
    }

    /// The preset menu of the current scene (sends `scene.preset` when the choice changes).
    private var presetPicker: some View {
        let scene = SceneCatalog.scenes[SceneShaders.clamped(mirror.scene)]
        return menu("Colours", name: "preset", titles: scene.presets.map(\.name), current: mirror.preset,
                    hint: "Chooses the colour preset of the scene") { index in
            port.send("scene.preset", [Double(index)])
        }
    }

    /// One slider per parameter of the current scene.
    private var parameterSliders: some View {
        let scene = SceneCatalog.scenes[SceneShaders.clamped(mirror.scene)]
        return ForEach(Array(scene.parameters.enumerated()), id: \.element.id) { index, parameter in
            parameterSlider(index: index, parameter: parameter)
        }
    }

    /// The slider of `parameter` at `index` (sends `scene.parameter [index, value]` when the value changes).
    private func parameterSlider(index: Int, parameter: SceneParameter) -> some View {
        let value = index < mirror.parameters.count ? mirror.parameters[index] : parameter.defaultValue
        let words = parameter.name + " " + String(format: "%.2f", value)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: words).font(.body)
            Slider(value: Binding(get: { value },
                                  set: { next in
                                      guard next != value else { return }
                                      port.send("scene.parameter", [Double(index), next])
                                  }),
                   in: parameter.minimum...parameter.maximum)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: parameter.name))
                .accessibilityValue(Text(verbatim: String(format: "%.2f", value)))
                .accessibilityHint(Text(verbatim: "Changes the scene's " + parameter.name.lowercased()))
                .accessibilityIdentifier(port.identifier("parameter-\(index)"))
        }
    }

    /// The animation time slider, 0…3600 s (sends `scene.time` when the value changes).
    private var timeSlider: some View {
        let seconds = mirror.animationTime
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Self.timeWords(seconds)).font(.body)
            Slider(value: Binding(get: { seconds },
                                  set: { next in
                                      guard next != seconds else { return }
                                      port.send("scene.time", [next])
                                  }),
                   in: WallpaperCore.timeRange)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Moment"))
                .accessibilityValue(Text(verbatim: Self.timeWords(seconds)))
                .accessibilityHint(Text(verbatim: "Chooses the moment of the animation that is exported"))
                .accessibilityIdentifier(port.identifier("time"))
        }
    }

    /// The motion toggle (sends `motion.enabled` when the choice changes).
    private var motionToggle: some View {
        let isOn = mirror.motion
        return Toggle(isOn: Binding(get: { isOn },
                                    set: { on in
                                        guard on != isOn else { return }
                                        port.send("motion.enabled", [on ? 1 : 0])
                                    })) {
            Text(verbatim: "Motion").font(.body)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Motion"))
        .accessibilityValue(Text(verbatim: isOn ? "On" : "Off"))
        .accessibilityHint(Text(verbatim: "Moves the preview; off shows the chosen moment"))
        .accessibilityIdentifier(port.identifier("motion"))
    }

    /// The Export button and the sentence of the last export.
    private var exportButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                guard let stillRenderer else {
                    exportMessage = Self.noRendererSentence
                    return
                }
                let output = presenter.export(using: stillRenderer)
                exportMessage = Self.sentence(output, export: presenter.stillExport)
            } label: {
                Text(verbatim: "Export").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Export"))
            .accessibilityHint(Text(verbatim: "Renders the framed picture at the device's size into a temporary file"))
            .accessibilityIdentifier(port.identifier("export"))
            if let exportMessage {
                Text(verbatim: exportMessage).font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("export-message"))
            }
        }
    }

    /// A menu titled `title` with the identifier name `name` over `titles`, calling `send` only when the choice
    /// changes.
    private func menu(_ title: String, name: String, titles: [String], current: Int, hint: String,
                      send: @escaping @MainActor (Int) -> Void) -> some View {
        let shown = min(max(current, 0), max(titles.count - 1, 0))
        return Picker(selection: Binding(get: { shown },
                                         set: { index in
                                             guard index != shown else { return }
                                             send(index)
                                         })) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, text in
                Text(verbatim: text).tag(index)
            }
        } label: {
            Text(verbatim: title)
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: titles.indices.contains(shown) ? titles[shown] : ""))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}
