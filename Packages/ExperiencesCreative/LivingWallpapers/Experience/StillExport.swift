// StillExport — feature 139 (A19-P02) T-A19-209 (FR-A19-205; clarification Q5; data-model.md "StillExport"; research
// D6). One export attempt of a wallpaper still, synchronous on the main actor between frames:
//
//   1. planned: the A19-P01 planner (`ExportPlanner.plan(project:maxEdge:)`) gives the exact size, or a refusal
//      (`no-limit`; `does-not-fit`, keeping the refusal so a retry can use its offered plan); then the format is
//      checked with `StillImageEncoder.isAvailable(_:)` before anything is rendered (`format-unavailable`);
//   2. rendered: the injected renderer draws the still at the plan's size and the project's animation time (in the
//      app the environment's timed still renderer, on the session's own render host; the render target is released
//      by `RenderHost.renderOffscreen` itself on every path) (`render` on a failure);
//   3. encoded: `StillImageEncoder.data(_:format:)`, opaque and tagged sRGB (`encoding`);
//   4. verified: the data read back through `ImageColorPipeline.verify(_:against:)` matches the plan's size and
//      profile (`verification`);
//   5. written: one file `wallpaper-<UUID>.<png|jpg|heic>` in the attempt's `TemporaryFolder`
//      (`LivingWallpapers-Export`); a failed write is reported as `encoding` (the encoded data could not be kept).
//
// A cancel flag (`cancel()`, or the test seam `cancelAfter`) is checked after each step: the attempt then ends
// `cancelled`. A cancel or a failure at any step removes that attempt's file, so nothing of the attempt is left. A new
// attempt first removes the file the previous one wrote, so the folder holds at most one file of this exporter. The
// template of a core project is always known; the planner's `unknown-template` is reported as `does-not-fit`.
import Foundation
import LivingWallpapersCore
import VisualCorePersistence
import VisualCoreRendering

/// One export attempt of a wallpaper still: plan, render, encode, verify, write (see the file header).
@MainActor
public final class StillExport {
    /// A step of the attempt, in order.
    public enum Step: String, CaseIterable, Sendable {
        /// The plan exists and the format is available.
        case planned
        /// The still was rendered at the plan's size.
        case rendered
        /// The still was encoded.
        case encoded
        /// The encoded data read back as planned.
        case verified
        /// The file was written.
        case written
    }

    /// Why an attempt failed.
    public enum FailureReason: String, CaseIterable, Sendable {
        /// The device reported no usable edge limit.
        case noLimit = "no-limit"
        /// The template's size does not fit the limits (see `lastRefusal` for the offered size).
        case doesNotFit = "does-not-fit"
        /// The format cannot be written on this system; refused before rendering.
        case formatUnavailable = "format-unavailable"
        /// The still could not be rendered (no experience open, a size the host refuses, a scene error).
        case render
        /// The still could not be encoded or its file could not be written.
        case encoding
        /// The file did not read back at the planned size and profile.
        case verification

        /// One sentence describing the failure.
        public var sentence: String {
            switch self {
            case .noLimit: return "This device reported no usable image size limit, so nothing can be exported."
            case .doesNotFit: return "The template is larger than this device can export."
            case .formatUnavailable: return "This device cannot write this file format."
            case .render: return "The picture could not be rendered."
            case .encoding: return "The picture could not be encoded or saved."
            case .verification: return "The file did not read back at the planned size and colour profile."
            }
        }
    }

    /// Where an attempt is.
    public enum State: Equatable, Sendable {
        /// No attempt yet.
        case idle
        /// The plan exists.
        case planned(ExportPlan)
        /// The still was rendered.
        case rendered
        /// The still was encoded.
        case encoded
        /// The encoded data read back as planned.
        case verified
        /// The file was written at the URL.
        case written(URL)
        /// The attempt was cancelled; its file, if any, was removed.
        case cancelled
        /// The attempt failed; its file, if any, was removed.
        case failed(FailureReason)
    }

    /// A finished attempt: the written file, what it reads back as, and the plan.
    public struct Output: Equatable, Sendable {
        /// The written file.
        public let url: URL
        /// The file read back (size, colour space name, bytes).
        public let result: ExportResult
        /// The plan it was made from.
        public let plan: ExportPlan
    }

    /// The renderer of a still: width and height in pixels and the animation time in seconds (main actor).
    public typealias Render = @MainActor (Int, Int, Double) throws(OffscreenRenderError) -> StillImage

    /// The folder the attempts write into.
    public let folder: TemporaryFolder
    /// Where the last attempt is.
    public private(set) var state: State = .idle
    /// The planner's refusal of the last attempt (its `offeredPlan(format:)` is the retry); nil otherwise.
    public private(set) var lastRefusal: ExportRefusal?
    /// The render error of the last attempt; nil otherwise.
    public private(set) var lastRenderError: OffscreenRenderError?
    /// The last successful output; nil after a failed or cancelled attempt.
    public private(set) var lastOutput: Output?
    /// The steps the last attempt completed, in order.
    public private(set) var completedSteps: [Step] = []
    /// Whether a cancel was asked for during the running attempt.
    private var cancelRequested = false

    /// An exporter writing into `folder` (default `LivingWallpapers-Export` in the temporary directory).
    public init(folder: TemporaryFolder = TemporaryFolder(name: "LivingWallpapers-Export")) {
        self.folder = folder
    }

    /// Asks the running attempt to stop after its current step.
    public func cancel() {
        cancelRequested = true
    }

    /// Plans `project` with `maxEdge` and runs the attempt with `render`; `cancelAfter` (a test seam) cancels after
    /// that step. Returns the output, or nil when the attempt failed or was cancelled (see `state`).
    @discardableResult
    public func run(project: WallpaperProject, maxEdge: Int, render: Render, cancelAfter: Step? = nil) -> Output? {
        begin()
        switch ExportPlanner.plan(project: project, maxEdge: maxEdge) {
        case .success(let plan):
            return proceed(plan: plan, time: project.animationTime, render: render, cancelAfter: cancelAfter)
        case .failure(let refusal):
            lastRefusal = refusal
            switch refusal {
            case .noLimit: return fail(.noLimit, file: nil)
            case .doesNotFit, .unknownTemplate: return fail(.doesNotFit, file: nil)
            }
        }
    }

    /// Runs the attempt with an existing `plan` (for example a refusal's offered plan on a retry) at the animation
    /// `time`; `cancelAfter` (a test seam) cancels after that step.
    @discardableResult
    public func run(plan: ExportPlan, time: Double, render: Render, cancelAfter: Step? = nil) -> Output? {
        begin()
        return proceed(plan: plan, time: time, render: render, cancelAfter: cancelAfter)
    }

    /// Removes the file of `output` (once the caller has handed it on); returns whether a file was removed.
    @discardableResult
    public func discard(_ output: Output) -> Bool {
        if lastOutput == output { lastOutput = nil }
        guard FileManager.default.fileExists(atPath: output.url.path) else { return false }
        return (try? FileManager.default.removeItem(at: output.url)) != nil
    }

    /// The file extension of `format`: png, jpg or heic.
    public static func fileExtension(_ format: ExportFormat) -> String {
        switch format {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        }
    }

    /// The VisualCore encoder format of `format`.
    public static func imageFormat(_ format: ExportFormat) -> StillImageFormat {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }

    // MARK: Steps

    /// Clears the last attempt (removing its file) and the cancel flag.
    private func begin() {
        if let previous = lastOutput { discard(previous) }
        lastOutput = nil
        lastRefusal = nil
        lastRenderError = nil
        completedSteps = []
        cancelRequested = false
        state = .idle
    }

    /// The steps after planning (see the file header).
    private func proceed(plan: ExportPlan, time: Double, render: Render, cancelAfter: Step?) -> Output? {
        let format = Self.imageFormat(plan.format)
        guard StillImageEncoder.isAvailable(format) else { return fail(.formatUnavailable, file: nil) }
        state = .planned(plan)
        if stop(after: .planned, cancelAfter, file: nil) { return nil }

        let image: StillImage
        do {
            image = try render(plan.width, plan.height, time)
        } catch {
            lastRenderError = error
            return fail(.render, file: nil)
        }
        state = .rendered
        if stop(after: .rendered, cancelAfter, file: nil) { return nil }

        let data: Data
        do {
            data = try StillImageEncoder.data(image, format: format)
        } catch {
            return fail(.encoding, file: nil)
        }
        state = .encoded
        if stop(after: .encoded, cancelAfter, file: nil) { return nil }

        guard ImageColorPipeline.verify(data, against: plan).isEmpty,
              let result = ImageColorPipeline.inspect(data) else { return fail(.verification, file: nil) }
        state = .verified
        if stop(after: .verified, cancelAfter, file: nil) { return nil }

        let url: URL
        do {
            url = try folder.makeFileURL(prefix: "wallpaper", extension: Self.fileExtension(plan.format))
        } catch {
            return fail(.encoding, file: nil)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return fail(.encoding, file: url)
        }
        state = .written(url)
        if stop(after: .written, cancelAfter, file: url) { return nil }
        let output = Output(url: url, result: result, plan: plan)
        lastOutput = output
        return output
    }

    /// Records `step` as completed; when a cancel was asked for (or `cancelAfter` is `step`) removes `file` and ends
    /// the attempt `cancelled`, returning true.
    private func stop(after step: Step, _ cancelAfter: Step?, file: URL?) -> Bool {
        completedSteps.append(step)
        if cancelAfter == step { cancelRequested = true }
        guard cancelRequested else { return false }
        remove(file)
        state = .cancelled
        return true
    }

    /// Removes `file` and ends the attempt `failed(reason)`; returns nil.
    private func fail(_ reason: FailureReason, file: URL?) -> Output? {
        remove(file)
        state = .failed(reason)
        return nil
    }

    /// Removes `file` when it exists.
    private func remove(_ file: URL?) {
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.removeItem(at: file)
    }
}
