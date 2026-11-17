// ExportNotice — feature 140 (A19-P03) T-A19-305 (FR-A19-302; clarification Q2). The one-sentence notice the editor
// shows beside the template picker when an export cannot be planned at the template's exact size: the template's
// pixel size, the device's limit and the size offered instead. A plan that fits gets no notice. Pure text.
import Foundation
import VisualCoreScenes

/// The fallback notice of an export plan.
public enum ExportNotice {
    /// The notice for `refusal`, with `limit` the export edge limit the presenter reads.
    ///
    /// - `doesNotFit`: "<Device> is <W> × <H> pixels, larger than this device can render (<limit>). It will be
    ///   exported at <w> × <h> instead.", where W × H is the template's size in `orientation` (the refusal names the
    ///   template but not its orientation, so the caller passes it; portrait by default) and w × h the offered size.
    ///   A template id that ``CanvasTemplates`` does not have reads as `unknownTemplate`.
    /// - `noLimit`: "Open a picture to export it."
    /// - `unknownTemplate`: "This device size is not known."
    public static func notice(for refusal: ExportRefusal, limit: Int,
                              orientation: Orientation = .portrait) -> String? {
        switch refusal {
        case .noLimit:
            return "Open a picture to export it."
        case .unknownTemplate:
            return "This device size is not known."
        case let .doesNotFit(id, offered):
            guard let template = CanvasTemplates.template(id: id) else { return "This device size is not known." }
            let size = template.size(for: orientation)
            return "\(template.device) is \(size.width) × \(size.height) pixels, larger than this device can render "
                + "(\(limit)). It will be exported at \(offered.width) × \(offered.height) instead."
        }
    }

    /// The notice for a planner `result` made for a project in `orientation`: nil for `.success` (the plan fits),
    /// otherwise ``notice(for:limit:orientation:)`` of the refusal.
    public static func notice(for result: Result<ExportPlan, ExportRefusal>, limit: Int,
                              orientation: Orientation) -> String? {
        switch result {
        case .success: return nil
        case .failure(let refusal): return notice(for: refusal, limit: limit, orientation: orientation)
        }
    }
}
