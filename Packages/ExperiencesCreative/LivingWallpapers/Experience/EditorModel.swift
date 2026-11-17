// EditorModel — feature 140 (A19-P03) T-A19-307, T-A19-309 (FR-A19-302–305; clarifications Q2–Q5; contracts/editor.md
// "Notice", "Result line", "Help", "Accessibility"). The testable state of the Living Wallpapers editor, kept out of
// SwiftUI so tests drive it without a view:
//
//   - Notice: ``notice(planned:limit:orientation:)`` is `ExportNotice`'s sentence for the planner's result at the
//     presenter's export limit and the current orientation (nil when the plan fits), shown beside the template
//     picker; ``offeredPlan(planned:format:)`` is the refusal's `offeredPlan(format:)`, which the button
//     "Export at <w> × <h>" (``offeredTitle(_:)``) exports.
//   - Outcome: ``finish(_:export:limit:orientation:port:)`` turns an attempt into one ``Outcome``: done (the result
//     line `ExportResultLine.line(plan:result:)`), failed (the reason's sentence) or the notice (a planner refusal).
//     Each outcome is announced exactly once through `ExperienceFeedback.announce` (the port's
//     `announce(_:kind:route:)` when a port is given): `.outcome` for done or failed, `.rejection` for the notice.
//   - Help: ``openHelp(from:)`` opens `HelpView` from the editor, and from the result once a file was written (the
//     "How to use it" button); ``closeHelp()`` closes it.
//   - Labels: ``labels(_:offeredPlan:resultLine:)`` lists every control's accessibility label with its current value,
//     for example "Scene, Ink Flow" or "Colour 2, red 0.40, green 0.20, blue 0.60"; the controls take their labels
//     from this list, so the tests read exactly what VoiceOver reads.
//
// No GL, Photos or system-wallpaper call; nothing here renders.
import Foundation
import LivingWallpapersCore
import Observation
import VisualCoreExperienceHost
import VisualCoreSimulation

/// One control's accessibility label: its identifier name, its title and its current value.
struct EditorLabel: Equatable, Sendable {
    /// The identifier name (`experience.a19.living-wallpapers.<name>`).
    let name: String
    /// The title, for example "Scene".
    let title: String
    /// The current value in words, for example "Ink Flow".
    let value: String

    /// The label VoiceOver reads: "<title>, <value>".
    var text: String { title + ", " + value }

    /// A label of `name` with `title` and `value`.
    init(name: String, title: String, value: String) {
        self.name = name
        self.title = title
        self.value = value
    }
}

/// The testable state of the editor (see the file header).
@MainActor
@Observable
final class EditorModel {
    /// The outcome of an export attempt.
    enum Outcome: Equatable, Sendable {
        /// A file was written; the value is its result line, for example "PNG, 1206 × 2622 pixels, sRGB".
        case done(String)
        /// The attempt failed or was cancelled; the value is the reason.
        case failed(String)
        /// The planner refused the template's exact size; the value is the notice.
        case notice(String)

        /// The text shown and announced.
        var text: String {
            switch self {
            case .done(let line): return "Exported " + line + "."
            case .failed(let reason): return reason
            case .notice(let notice): return notice
            }
        }

        /// The announcement kind: `.outcome` for done or failed, `.rejection` for the notice.
        var kind: AnnouncementKind {
            switch self {
            case .done, .failed: return .outcome
            case .notice: return .rejection
            }
        }
    }

    /// Where the help was opened from.
    enum HelpOrigin: String, Equatable, Sendable {
        /// The help button of the editor.
        case editor
        /// The "How to use it" button after a written export.
        case result
    }

    /// The title of the help view and of the result's help button.
    static let helpTitle = "How to use it"
    /// The reason shown when no experience is open to render.
    static let noRendererReason = "No picture is open to export."

    /// The route announcements go through (the shared one in the app; tests pass one with a recording sink).
    let route: ExperienceFeedback
    /// The outcome of the last export attempt; nil before the first.
    private(set) var outcome: Outcome?
    /// Where the open help was opened from; nil while it is closed.
    private(set) var helpOrigin: HelpOrigin?
    /// The number of announcements this model asked for (one per outcome).
    private(set) var announcementCount = 0

    /// A model announcing through `route`.
    init(route: ExperienceFeedback = .shared) {
        self.route = route
    }

    // MARK: Notice and offered plan

    /// The notice for the planner's `planned` result at the export `limit` in `orientation`; nil when it fits.
    static func notice(planned: Result<ExportPlan, ExportRefusal>, limit: Int,
                       orientation: Orientation) -> String? {
        ExportNotice.notice(for: planned, limit: limit, orientation: orientation)
    }

    /// The offered fallback plan of a refused `planned` result in `format`; nil when it fits or nothing is offered.
    static func offeredPlan(planned: Result<ExportPlan, ExportRefusal>, format: ExportFormat) -> ExportPlan? {
        guard case .failure(let refusal) = planned else { return nil }
        return refusal.offeredPlan(format: format)
    }

    /// The title of the offered export's button: "Export at <w> × <h>".
    static func offeredTitle(_ plan: ExportPlan) -> String {
        "Export at \(plan.width) × \(plan.height)"
    }

    // MARK: Outcome

    /// The outcome of an attempt of `export` that returned `output`, with the notice at `limit` in `orientation`
    /// for a planner refusal.
    static func outcome(_ output: StillExport.Output?, export: StillExport, limit: Int,
                        orientation: Orientation) -> Outcome {
        if let output { return .done(ExportResultLine.line(plan: output.plan, result: output.result)) }
        if let refusal = export.lastRefusal,
           let notice = ExportNotice.notice(for: refusal, limit: limit, orientation: orientation) {
            return .notice(notice)
        }
        switch export.state {
        case .cancelled: return .failed("The export was cancelled.")
        case .failed(let reason): return .failed(reason.sentence)
        default: return .failed("The export did not finish.")
        }
    }

    /// Records the outcome of an attempt of `export` that returned `output` and announces it once (through `port`
    /// when given, else straight through ``route``).
    func finish(_ output: StillExport.Output?, export: StillExport, limit: Int, orientation: Orientation,
                port: ExperienceActionPort? = nil) {
        record(Self.outcome(output, export: export, limit: limit, orientation: orientation), port: port)
    }

    /// Records that nothing could be exported because no experience is open, and announces it once.
    func finishWithoutRenderer(port: ExperienceActionPort? = nil) {
        record(.failed(Self.noRendererReason), port: port)
    }

    /// Records `outcome` and announces its text once with its kind.
    func record(_ outcome: Outcome, port: ExperienceActionPort? = nil) {
        self.outcome = outcome
        if helpOrigin == .result, resultLine == nil { helpOrigin = nil }
        announcementCount += 1
        if let port {
            port.announce(outcome.text, kind: outcome.kind, route: route)
        } else {
            route.announce(outcome.text, kind: outcome.kind)
        }
    }

    /// The result line after a written export; nil otherwise.
    var resultLine: String? {
        if case .done(let line) = outcome { return line }
        return nil
    }

    // MARK: Help

    /// Whether the help can be opened from `origin`: always from the editor, from the result after a written export.
    func canOpenHelp(from origin: HelpOrigin) -> Bool {
        origin == .editor || resultLine != nil
    }

    /// Opens the help from `origin`; returns false (and changes nothing) when it cannot be opened from there.
    @discardableResult
    func openHelp(from origin: HelpOrigin) -> Bool {
        guard canOpenHelp(from: origin) else { return false }
        helpOrigin = origin
        return true
    }

    /// Closes the help.
    func closeHelp() {
        helpOrigin = nil
    }

    /// Whether the help is open.
    var isHelpOpen: Bool { helpOrigin != nil }

    // MARK: Labels

    /// The orientation titles, by index.
    static let orientationTitles = ["Portrait", "Landscape"]
    /// The format titles, by index of `ExportFormat.allCases`.
    static let formatTitles = ["PNG", "JPEG", "HEIC"]

    /// A number with two decimals, for example "0.40".
    static func twoDecimals(_ value: Double) -> String { String(format: "%.2f", value) }

    /// The animation time in words: "12.5 seconds".
    static func seconds(_ value: Double) -> String { String(format: "%.1f", value) + " seconds" }

    /// The colour of slot `slot` (0…3) of the twelve `components` in words: "red 0.40, green 0.20, blue 0.60".
    static func colourWords(_ components: [Double], slot: Int) -> String {
        func at(_ index: Int) -> Double { index >= 0 && index < components.count ? components[index] : 0 }
        return "red " + twoDecimals(at(slot * 3)) + ", green " + twoDecimals(at(slot * 3 + 1)) + ", blue "
            + twoDecimals(at(slot * 3 + 2))
    }

    /// The title of colour slot `slot`: "Colour 1" … "Colour 4".
    static func colourTitle(_ slot: Int) -> String { "Colour \(slot + 1)" }

    /// Every control's label with its current value, in the controls' order: scene, colours (the preset), the
    /// scene's parameters, the four colour slots, reset colours, device, orientation, moment, format, motion,
    /// export, the offered export when `offeredPlan` is given, help, and the result's help when `resultLine` is given.
    static func labels(_ mirror: WallpaperMirror, offeredPlan: ExportPlan?,
                       resultLine: String?) -> [EditorLabel] {
        let scene = SceneCatalog.scenes[SceneShaders.clamped(mirror.scene)]
        let preset = scene.presets[min(max(mirror.preset, 0), scene.presets.count - 1)]
        var labels = [EditorLabel(name: "scene", title: "Scene", value: scene.name),
                      EditorLabel(name: "preset", title: "Colours", value: preset.name)]
        for (index, parameter) in scene.parameters.enumerated() {
            let value = index < mirror.parameters.count ? mirror.parameters[index] : parameter.defaultValue
            labels.append(EditorLabel(name: "parameter-\(index)", title: parameter.name, value: twoDecimals(value)))
        }
        for slot in 0..<WallpaperCore.colorSlots {
            labels.append(EditorLabel(name: "colour-\(slot)", title: colourTitle(slot),
                                      value: colourWords(mirror.colors, slot: slot)))
        }
        labels.append(EditorLabel(name: "reset-colours", title: "Reset colours",
                                  value: mirror.custom == 1 ? "edited, returns to " + preset.name
                                      : "showing " + preset.name))
        let template = mirror.templateDefinition
        let orientation = mirror.orientationValue
        let size = template.size(for: orientation)
        let format = formatTitles[min(max(mirror.format, 0), formatTitles.count - 1)]
        labels.append(EditorLabel(name: "template", title: "Device", value: template.device))
        labels.append(EditorLabel(name: "orientation", title: "Orientation",
                                  value: orientationTitles[mirror.orientation == 1 ? 1 : 0]))
        labels.append(EditorLabel(name: "time", title: "Moment", value: seconds(mirror.animationTime)))
        labels.append(EditorLabel(name: "format", title: "Format", value: format))
        labels.append(EditorLabel(name: "motion", title: "Motion", value: mirror.motion ? "On" : "Off"))
        labels.append(EditorLabel(name: "export", title: "Export",
                                  value: "\(format), \(size.width) × \(size.height) pixels"))
        if let offeredPlan {
            labels.append(EditorLabel(name: "export-offered", title: offeredTitle(offeredPlan),
                                      value: "\(format), \(offeredPlan.width) × \(offeredPlan.height) pixels"))
        }
        labels.append(EditorLabel(name: "help", title: "Help", value: helpTitle))
        if let resultLine {
            labels.append(EditorLabel(name: "result-help", title: helpTitle, value: "after " + resultLine))
        }
        return labels
    }

    /// Every control's label with its current value for `mirror`, with this model's result line and the offered
    /// plan of `planned` (see ``labels(_:offeredPlan:resultLine:)``).
    func labels(_ mirror: WallpaperMirror, planned: Result<ExportPlan, ExportRefusal>) -> [EditorLabel] {
        let format = ExportFormat.allCases[min(max(mirror.format, 0), ExportFormat.allCases.count - 1)]
        return Self.labels(mirror, offeredPlan: Self.offeredPlan(planned: planned, format: format),
                           resultLine: resultLine)
    }
}
