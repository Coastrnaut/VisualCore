// WallpaperControls — feature 139 (A19-P02) T-A19-207, T-A19-209 (FR-A19-204, FR-A19-205, FR-A19-206; clarification
// Q5). The native controls of Living Wallpapers, modelled on Ambient Clock's: every control reads the presenter's
// mirror, sends through the action port only when its value changes, and has an accessible label, hint and the
// identifier `experience.a19.living-wallpapers.<name>` (`ExperienceActionPort.identifier`):
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
//     (`experienceStillRenderer`) and shows the outcome in `export-message`. Without a renderer (no experience open)
//     it says so.
//
// Feature 140 (A19-P03) T-A19-303, T-A19-307, T-A19-309 (FR-A19-301–305; clarifications Q1–Q5; contracts/editor.md):
//   - colour editor: one colour well per slot, `colour-0` … `colour-3` (sRGB components, each clamped to 0…1 and
//     rounded to 1/1000 → `preset.color [slot, r, g, b]`), and `reset-colours` (→ `preset.reset []`);
//   - beside the template picker, the notice of `ExportNotice` for the planner's result at the presenter's export
//     limit (`maxEdge`) and the current orientation, with the button "Export at <w> × <h>" (`export-offered`), which
//     exports the refusal's `offeredPlan(format:)` through `StillExport.run(plan:time:render:)`;
//   - after a written export, the result line (`ExportResultLine.line(plan:result:)`) and the "How to use it" button
//     (`result-help`); the editor's `help` button; both open `HelpView` as a sheet;
//   - every control's accessibility label carries its current value (`EditorModel.labels`), for example
//     "Scene, Ink Flow"; sliders also report their value so a swipe reads the new one;
//   - each export outcome is announced once (`EditorModel.finish`, `.outcome` for done or failed, `.rejection` for
//     the notice);
//   - at an accessibility Dynamic Type size (accessibility-one to accessibility-five) every row stacks its title above
//     its control, so the controls form one column no wider than the canvas.
// No Photos or system-wallpaper call.
import CoreGraphics
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
    /// The editor's notice, outcome, help and labels.
    let model: EditorModel
    /// The open experience's still renderer; nil when no experience is open.
    @Environment(\.experienceStillRenderer) private var stillRenderer
    /// The Dynamic Type size: an accessibility size stacks every row in one column.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The orientation titles, by index.
    static let orientationTitles = EditorModel.orientationTitles
    /// The format titles, by index of `ExportFormat.allCases`.
    static let formatTitles = EditorModel.formatTitles
    /// The sentence shown when no experience is open to render.
    static let noRendererSentence = EditorModel.noRendererReason

    /// The animation time in words: "Moment 12.5 seconds".
    static func timeWords(_ seconds: Double) -> String {
        "Moment " + String(format: "%.1f", seconds) + " seconds"
    }

    /// The sentence of an export's outcome (A19-P02): the output's size, format and kilobytes, or the reason (with
    /// the planner's sentence for a refusal).
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

    /// The sRGB colour of slot `slot` of the twelve `components`.
    static func cgColor(_ components: [Double], slot: Int) -> CGColor {
        func at(_ index: Int) -> CGFloat { index < components.count ? CGFloat(components[index]) : 0 }
        return CGColor(srgbRed: at(slot * 3), green: at(slot * 3 + 1), blue: at(slot * 3 + 2), alpha: 1)
    }

    /// The sRGB components of `color`, each clamped to 0…1 and rounded to 1/1000; nil when it cannot be converted.
    static func components(of color: CGColor) -> [Double]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
              let parts = converted.components, parts.count >= 3 else { return nil }
        return parts.prefix(3).map { part in
            let value = Double(part)
            guard value.isFinite else { return 0 }
            return (min(max(value, 0), 1) * 1000).rounded() / 1000
        }
    }

    /// Whether the rows stack in one column (an accessibility Dynamic Type size).
    private var isOneColumn: Bool { dynamicTypeSize.isAccessibilitySize }

    /// The controls.
    var body: some View {
        let planned = presenter.plannedExport
        let labels = Dictionary(model.labels(mirror, planned: planned).map { ($0.name, $0) },
                                uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "Living Wallpapers").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                helpButton(labels["help"])
            }
            scenePicker(labels)
            presetPicker(labels)
            parameterSliders(labels)
            colourEditor(labels)
            menu("Device", name: "template", titles: CanvasTemplates.all.map(\.device), current: mirror.template,
                 label: labels["template"], hint: "Chooses the device whose screen size is exported") { index in
                port.send("canvas.template", [Double(index)])
            }
            noticeRow(planned: planned, labels: labels)
            menu("Orientation", name: "orientation", titles: Self.orientationTitles, current: mirror.orientation,
                 label: labels["orientation"], hint: "Chooses portrait or landscape") { index in
                port.send("canvas.orientation", [Double(index)])
            }
            timeSlider(labels["time"])
            menu("Format", name: "format", titles: Self.formatTitles, current: mirror.format,
                 label: labels["format"], hint: "Chooses the file format of the exported still") { index in
                port.send("export.format", [Double(index)])
            }
            motionToggle(labels["motion"])
            exportButton(labels)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: Binding(get: { model.isHelpOpen },
                                    set: { open in if !open { model.closeHelp() } })) {
            HelpView(done: { model.closeHelp() })
        }
    }

    /// The text VoiceOver reads for `label`, or `fallback` when the list has none.
    private func spoken(_ label: EditorLabel?, _ fallback: String) -> Text {
        Text(verbatim: label?.text ?? fallback)
    }

    /// A row of `title` and `control`: side by side, or stacked at an accessibility Dynamic Type size.
    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        let layout = isOneColumn ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Text(verbatim: title).font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            if !isOneColumn { Spacer(minLength: 8) }
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The scene menu (sends `scene.select` when the choice changes).
    private func scenePicker(_ labels: [String: EditorLabel]) -> some View {
        menu("Scene", name: "scene", titles: SceneCatalog.scenes.map(\.name), current: mirror.scene,
             label: labels["scene"], hint: "Chooses the procedural scene") { index in
            port.send("scene.select", [Double(index)])
        }
    }

    /// The preset menu of the current scene (sends `scene.preset` when the choice changes).
    private func presetPicker(_ labels: [String: EditorLabel]) -> some View {
        let scene = SceneCatalog.scenes[SceneShaders.clamped(mirror.scene)]
        return menu("Colours", name: "preset", titles: scene.presets.map(\.name), current: mirror.preset,
                    label: labels["preset"], hint: "Chooses the colour preset of the scene") { index in
            port.send("scene.preset", [Double(index)])
        }
    }

    /// One slider per parameter of the current scene.
    private func parameterSliders(_ labels: [String: EditorLabel]) -> some View {
        let scene = SceneCatalog.scenes[SceneShaders.clamped(mirror.scene)]
        return ForEach(Array(scene.parameters.enumerated()), id: \.element.id) { index, parameter in
            parameterSlider(index: index, parameter: parameter, label: labels["parameter-\(index)"])
        }
    }

    /// The slider of `parameter` at `index` (sends `scene.parameter [index, value]` when the value changes).
    private func parameterSlider(index: Int, parameter: SceneParameter, label: EditorLabel?) -> some View {
        let value = index < mirror.parameters.count ? mirror.parameters[index] : parameter.defaultValue
        let words = parameter.name + " " + String(format: "%.2f", value)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: words).font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { value },
                                  set: { next in
                                      guard next != value else { return }
                                      port.send("scene.parameter", [Double(index), next])
                                  }),
                   in: parameter.minimum...parameter.maximum)
                .frame(minHeight: 44)
                .accessibilityLabel(spoken(label, parameter.name))
                .accessibilityValue(Text(verbatim: String(format: "%.2f", value)))
                .accessibilityHint(Text(verbatim: "Changes the scene's " + parameter.name.lowercased()))
                .accessibilityIdentifier(port.identifier("parameter-\(index)"))
        }
    }

    /// The four colour wells and the reset button (feature 140).
    private func colourEditor(_ labels: [String: EditorLabel]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<WallpaperCore.colorSlots, id: \.self) { slot in
                colourWell(slot: slot, label: labels["colour-\(slot)"])
            }
            Button {
                port.send("preset.reset")
            } label: {
                Text(verbatim: "Reset colours").frame(minHeight: 44)
            }
            .disabled(mirror.custom == 0)
            .accessibilityLabel(spoken(labels["reset-colours"], "Reset colours"))
            .accessibilityHint(Text(verbatim: "Returns to the preset's own colours"))
            .accessibilityIdentifier(port.identifier("reset-colours"))
        }
    }

    /// The colour well of `slot` (sends `preset.color [slot, r, g, b]` when the colour changes).
    private func colourWell(slot: Int, label: EditorLabel?) -> some View {
        let shown = Array(mirror.colors[min(slot * 3, mirror.colors.count)..<min(slot * 3 + 3, mirror.colors.count)])
        let title = EditorModel.colourTitle(slot)
        return row(title) {
            ColorPicker(selection: Binding(get: { Self.cgColor(mirror.colors, slot: slot) },
                                           set: { color in
                                               guard let next = Self.components(of: color), next != shown else {
                                                   return
                                               }
                                               port.send("preset.color", [Double(slot)] + next)
                                           }),
                        supportsOpacity: false) {
                Text(verbatim: title)
            }
            .labelsHidden()
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(spoken(label, title))
            .accessibilityHint(Text(verbatim: "Edits this colour of the preset"))
            .accessibilityIdentifier(port.identifier("colour-\(slot)"))
        }
    }

    /// The notice beside the template picker and the button that exports the offered size; nothing when it fits.
    @ViewBuilder
    private func noticeRow(planned: Result<ExportPlan, ExportRefusal>, labels: [String: EditorLabel]) -> some View {
        if let notice = EditorModel.notice(planned: planned, limit: presenter.maxEdge,
                                           orientation: mirror.orientationValue) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: notice).font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("export-notice"))
                let format = ExportFormat.allCases[min(max(mirror.format, 0), ExportFormat.allCases.count - 1)]
                if let offered = EditorModel.offeredPlan(planned: planned, format: format) {
                    Button {
                        runExport(offered: offered)
                    } label: {
                        Text(verbatim: EditorModel.offeredTitle(offered)).frame(minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityLabel(spoken(labels["export-offered"], EditorModel.offeredTitle(offered)))
                    .accessibilityHint(Text(verbatim: "Renders the framed picture at the offered size"))
                    .accessibilityIdentifier(port.identifier("export-offered"))
                }
            }
        }
    }

    /// The animation time slider, 0…3600 s (sends `scene.time` when the value changes).
    private func timeSlider(_ label: EditorLabel?) -> some View {
        let seconds = mirror.animationTime
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Self.timeWords(seconds)).font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { seconds },
                                  set: { next in
                                      guard next != seconds else { return }
                                      port.send("scene.time", [next])
                                  }),
                   in: WallpaperCore.timeRange)
                .frame(minHeight: 44)
                .accessibilityLabel(spoken(label, "Moment"))
                .accessibilityValue(Text(verbatim: EditorModel.seconds(seconds)))
                .accessibilityHint(Text(verbatim: "Chooses the moment of the animation that is exported"))
                .accessibilityIdentifier(port.identifier("time"))
        }
    }

    /// The motion toggle (sends `motion.enabled` when the choice changes).
    private func motionToggle(_ label: EditorLabel?) -> some View {
        let isOn = mirror.motion
        return Toggle(isOn: Binding(get: { isOn },
                                    set: { on in
                                        guard on != isOn else { return }
                                        port.send("motion.enabled", [on ? 1 : 0])
                                    })) {
            Text(verbatim: "Motion").font(.body)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(spoken(label, "Motion"))
        .accessibilityHint(Text(verbatim: "Moves the preview; off shows the chosen moment"))
        .accessibilityIdentifier(port.identifier("motion"))
    }

    /// The help button of the editor.
    private func helpButton(_ label: EditorLabel?) -> some View {
        Button {
            model.openHelp(from: .editor)
        } label: {
            Text(verbatim: "Help").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(spoken(label, "Help"))
        .accessibilityHint(Text(verbatim: "Opens how to save the image and make it your wallpaper"))
        .accessibilityIdentifier(port.identifier("help"))
    }

    /// Runs the export at the template's exact size, or at `offered`, and records its outcome once.
    private func runExport(offered: ExportPlan?) {
        guard let stillRenderer else {
            model.finishWithoutRenderer(port: port)
            return
        }
        let output: StillExport.Output?
        if let offered {
            output = presenter.export(plan: offered, using: stillRenderer)
        } else {
            output = presenter.export(using: stillRenderer)
        }
        model.finish(output, export: presenter.stillExport, limit: presenter.maxEdge,
                     orientation: mirror.orientationValue, port: port)
    }

    /// The Export button, the outcome of the last export and, after a written export, the "How to use it" button.
    private func exportButton(_ labels: [String: EditorLabel]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                runExport(offered: nil)
            } label: {
                Text(verbatim: "Export").frame(minHeight: 44)
            }
            .accessibilityLabel(spoken(labels["export"], "Export"))
            .accessibilityHint(Text(verbatim: "Renders the framed picture at the device's size into a temporary file"))
            .accessibilityIdentifier(port.identifier("export"))
            if let outcome = model.outcome {
                Text(verbatim: outcome.text).font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("export-message"))
            }
            if model.resultLine != nil {
                Button {
                    model.openHelp(from: .result)
                } label: {
                    Text(verbatim: EditorModel.helpTitle).frame(minHeight: 44)
                }
                .accessibilityLabel(spoken(labels["result-help"], EditorModel.helpTitle))
                .accessibilityHint(Text(verbatim: "Opens how to save the image and make it your wallpaper"))
                .accessibilityIdentifier(port.identifier("result-help"))
            }
        }
    }

    /// A menu titled `title` with the identifier name `name` over `titles`, calling `send` only when the choice
    /// changes; its accessibility label is `label` (title and current value).
    private func menu(_ title: String, name: String, titles: [String], current: Int, label: EditorLabel?,
                      hint: String, send: @escaping @MainActor (Int) -> Void) -> some View {
        let shown = min(max(current, 0), max(titles.count - 1, 0))
        let value = titles.indices.contains(shown) ? titles[shown] : ""
        return row(title) {
            Picker(selection: Binding(get: { shown },
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
            .labelsHidden()
            .frame(minHeight: 44)
            .accessibilityLabel(spoken(label, title + ", " + value))
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityIdentifier(port.identifier(name))
        }
    }
}
