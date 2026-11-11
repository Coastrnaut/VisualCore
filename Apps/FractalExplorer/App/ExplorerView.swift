// ExplorerView.swift — the explorer screen (feature 026 T-A03-104; feature 027 T-A03-204): an accessible mode picker,
// the mode explanation, and the GPU picture on VisualCore's render host (RenderSurface), with the CPU-reference preview
// as the fallback when the shader cannot run. The app owns no EGL context.
import CoreGraphics
import FractalExplorerCore
import SwiftUI
import VisualCoreMath
import VisualCoreParameters
import VisualCorePersistence
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreScenes
import VisualCoreUI

/// The explorer's state, its GPU scene on VisualCore's render host, and the CPU-reference preview used as the fallback
/// picture when the shader cannot run (feature 027 T-A03-204; clarification 5).
@MainActor
@Observable
final class ExplorerModel {
    /// The fractal state (mode, viewport, seed, cap, radius); every change reaches the next frame.
    var state: FractalState {
        didSet {
            guard state != oldValue else { return }
            scene.snapshot.state = state
            if usingFallback { refresh() }
        }
    }
    /// The GPU scene (VisualCore FullScreenShaderScene inside).
    let scene: FractalScene
    /// The one render host (VisualCore's audited EGL host); nil if it could not start.
    private(set) var host: RenderHost?
    /// The latest CPU preview for the current request (fallback only).
    private(set) var preview: FractalPreview?
    /// The identifier of the latest preview request.
    private(set) var requestID = 0
    /// Preview results that arrived for an older request and were discarded (tests).
    private(set) var droppedResults = 0
    private var task: Task<Void, Never>?

    // MARK: Palettes (feature 027 T-A03-206; FR-A03-203)

    /// The offered VisualCore built-in palettes (Monochrome omitted: two stops make poor escape bands).
    static let paletteIDs = Bookmark.paletteIDs
    /// The selected palette.
    var paletteID: String { didSet { if Self.paletteIDs.contains(paletteID) { scene.snapshot.paletteID = paletteID } else { paletteID = oldValue } } }
    /// Palette animation along the bands; defaults to off under Reduce Motion.
    var animate: Bool { didSet { scene.snapshot.animate = animate } }

    /// `fragment` is a test seam (an invalid source exercises the fallback); `system` reads Reduce Motion (default: the
    /// system's, through VisualCoreUI's observer).
    // MARK: Bookmarks (feature 028 T-A03-305; FR-A03-304)

    /// The saved locations (VisualCore NamedLibrary of `Bookmark`).
    var bookmarks: BookmarkLibrary
    /// The last bookmark operation's failure, shown as an alert; nil when there is none.
    var bookmarkError: String?
    /// Shown after opening a bookmark whose view this device cannot show at full precision (feature 028 T-A03-307;
    /// US3; clarification 2); cleared by the next zoom, pan or reset.
    private(set) var bookmarkNote: String?

    /// `fragment` is a test seam (an invalid source exercises the fallback); `system` reads Reduce Motion (default: the
    /// system's, through VisualCoreUI's observer); `bookmarksDirectory` defaults to `Application Support/Bookmarks`
    /// (UI tests pass `-uitestTemporaryBookmarks` for a fresh folder per launch).
    init(size: Vec2 = Vec2(390, 844), fragment: String = FractalShaders.fragment,
         system: SystemAccessibility = SystemAccessibilityObserver.systemValues(),
         bookmarksDirectory: URL? = nil) {
        bookmarks = .bookmarks(directory: bookmarksDirectory ?? Self.defaultBookmarksDirectory())
        let initial = FractalState(size: size)
        state = initial
        paletteID = "sunset"
        animate = !system.reduceMotion
        scene = FractalScene(snapshot: .init(state: initial, paletteID: "sunset", animate: !system.reduceMotion), fragment: fragment)
        host = try? RenderHost(scene: scene)
        host?.pointerHandler = { [weak self] event in self?.handle(event) }
        if usingFallback { refresh() }
    }

    // MARK: Gestures (feature 027 T-A03-205; FR-A03-202; clarification 4)

    private var pointers = PointerTracker()
    private var pinch = PinchRecognizer()
    private var lastPoint: [Int: Vec2] = [:]
    /// True while a two-finger pinch is driving the view.
    private(set) var pinching = false

    // MARK: Precision limit (feature 027 T-A03-207; FR-A03-206; clarification 2)

    /// What the precision banner shows.
    enum PrecisionNotice: Equatable {
        case none, near, reached
        var text: String? {
            switch self {
            case .none: nil
            case .near: "Near precision limit — details may blur"
            case .reached: "Precision limit reached — zoom stops here"
            }
        }
    }

    /// Test seam: the shader's mantissa bits (default: the host's reported fragment precision, highp → mediump → 10).
    var mantissaBitsOverride: Int?
    /// Test seam: device pixels per point (default: the host view's display scale, else 2).
    var pixelsPerPointOverride: Double?
    /// The current precision notice.
    private(set) var notice = PrecisionNotice.none
    /// VoiceOver announcements made for notice changes (tests).
    private(set) var announcements: [String] = []

    /// Where the precision assumption comes from (feature 027 T-A03-209; US4 AC3), shown under the banner.
    var precisionSource: String {
        if let bits = mantissaBitsOverride { return "Shader precision: \(bits) bits (test setting)" }
        return Self.precisionSource(highp: host?.capabilities.fragmentHighp, mediump: host?.capabilities.fragmentMediump)
    }

    /// Describes the precision the limit is computed from: highp, else mediump, else the conservative 10-bit assumption
    /// with the reason.
    static func precisionSource(highp: RenderCapabilities.ShaderPrecision?,
                                mediump: RenderCapabilities.ShaderPrecision?) -> String {
        if let h = highp, h.isSupported, h.precisionBits > 0 { return "Shader precision: highp, \(h.precisionBits) bits" }
        if let m = mediump, m.isSupported, m.precisionBits > 0 {
            return "Shader precision: mediump, \(m.precisionBits) bits — the graphics driver reported no usable highp floats"
        }
        return "Shader precision: assumed 10 bits — the graphics driver reported no usable highp or mediump float precision"
    }

    /// The mantissa bits the shader works with.
    var mantissaBits: Int { mantissaBitsOverride ?? host?.capabilities.fragmentMantissaBits() ?? 10 }
    /// Device pixels per point.
    var pixelsPerPoint: Double {
        pixelsPerPointOverride ?? host.map { Double($0.view.traitCollection.displayScale) }.flatMap { $0 > 0 ? $0 : nil } ?? 2
    }

    /// The canvas's spoken description: the state's, plus the precision notice when there is one.
    var canvasDescription: String {
        notice.text.map { "\(state.spokenDescription). \($0)" } ?? state.spokenDescription
    }

    static func defaultBookmarksDirectory() -> URL {
        if ProcessInfo.processInfo.arguments.contains("-uitestTemporaryBookmarks") {
            return FileManager.default.temporaryDirectory.appendingPathComponent("uitest-bookmarks-\(UUID().uuidString)")
        }
        return BookmarkLibrary.defaultDirectory(named: "Bookmarks")
    }

    /// Re-reads the bookmark folder (the sheet opens).
    func reloadBookmarks() { bookmarks.reload() }

    /// Saves the current view under `name`; a failure leaves the list and the view unchanged and sets `bookmarkError`.
    @discardableResult
    func saveBookmark(name: String) -> BookmarkLibrary.Entry? {
        let precision = PrecisionMode(viewport: state.viewport, mantissaBits: mantissaBits, pixelsPerPoint: pixelsPerPoint)
        do {
            return try bookmarks.save(Bookmark(state: state, paletteID: paletteID, precision: precision), name: name)
        } catch {
            bookmarkError = "The bookmark was not saved. \(Self.describe(error))"
            return nil
        }
    }

    /// Opens a bookmark: mode, seed, cap, radius and palette, then its framing at the current canvas size through
    /// `apply` (so the precision clamp of feature 027 applies).
    func open(_ id: UUID) {
        guard let b = bookmarks.entry(id)?.payload else { return }
        let target = b.state(size: state.viewport.size)
        state = target
        paletteID = b.paletteID
        apply(target.viewport)
        if state.viewport.unitsPerPoint > target.viewport.unitsPerPoint {
            bookmarkNote = Self.bookmarkNoteText(savedBits: b.precision.mantissaBits, bits: mantissaBits)
        }
    }

    /// The note for a bookmark opened at the clamp.
    static func bookmarkNoteText(savedBits: Int, bits: Int) -> String {
        savedBits > bits
            ? "Saved at higher precision (\(savedBits) bits); shown at this device's limit (\(bits) bits)"
            : "Shown at this device's precision limit (\(bits) bits)"
    }

    /// Go to coordinates (feature 028 T-A03-309; FR-A03-305; clarification 1): centers the typed point at the typed
    /// magnification (span = default width ÷ zoom) through `apply`, so the precision clamp applies. Invalid input
    /// changes nothing and returns the problem.
    @discardableResult
    func goTo(real: String, imaginary: String, zoom: String, locale: Locale = .current) -> GoToError? {
        switch GoToInput.parse(real: real, imaginary: imaginary, zoom: zoom, locale: locale) {
        case .success(let target):
            apply(target.framing(for: state.mode).viewport(size: state.viewport.size))
            return nil
        case .failure(let error):
            return error
        }
    }

    /// Renames a bookmark.
    func renameBookmark(_ id: UUID, to name: String) { perform { try $0.rename(id, to: name) } }
    /// Marks or unmarks a favorite.
    func setFavorite(_ id: UUID, _ favorite: Bool) { perform { try $0.setFavorite(id, favorite) } }
    /// Deletes a bookmark.
    func deleteBookmark(_ id: UUID) { perform { try $0.delete(id) } }

    private func perform(_ op: (inout BookmarkLibrary) throws -> Void) {
        do { try op(&bookmarks) } catch { bookmarkError = "The change was not saved. \(Self.describe(error))" }
    }

    private static func describe(_ error: any Error) -> String {
        switch error as? StoreProblem {
        case .writeFailed: "The file could not be written."
        case .notFound: "The bookmark no longer exists."
        default: "The bookmark could not be stored."
        }
    }

    /// Applies a new viewport, clamping its scale so one device pixel never falls below one representable step of the
    /// coordinates (VisualCoreMath.PrecisionAdvisor with the shader's mantissa bits), then updates the notice.
    func apply(_ viewport: PlaneViewport) {
        bookmarkNote = nil
        var v = viewport
        let magnitude = max(abs(v.center.x), abs(v.center.y))
        let minStep = PrecisionAdvisor.minimumPixelStep(mantissaBits: mantissaBits, magnitude: magnitude)
        let minUnitsPerPoint = minStep * pixelsPerPoint
        var clamped = false
        if v.unitsPerPoint < minUnitsPerPoint {
            v = PlaneViewport(center: v.center, unitsPerPoint: minUnitsPerPoint, size: v.size)
            clamped = true
        }
        if v != state.viewport { state.viewport = v }
        updateNotice(clamped: clamped)
    }

    private func updateNotice(clamped: Bool) {
        let v = state.viewport
        // One rule for the banner and for saved bookmarks (FractalExplorerCore.PrecisionMode.level).
        let level = PrecisionMode.level(viewport: v, mantissaBits: mantissaBits, pixelsPerPoint: pixelsPerPoint)
        let next: PrecisionNotice = clamped || level == .beyondLimit ? .reached : (level == .reliable ? .none : .near)
        guard next != notice else { return }
        notice = next
        if let text = next.text {
            announcements.append(text)
            AccessibilityNotification.Announcement(text).post()
        }
    }

    /// One canvas touch event. Two fingers (VisualCore PointerTracker order, PinchRecognizer state) pinch and pan
    /// incrementally per event: from the fingers' previous positions to their current ones, the view pans by the
    /// midpoint's movement and zooms by the distance ratio about the new midpoint — so the plane point under the
    /// midpoint follows it exactly. One finger pans by its own movement, so a finger left after a pinch keeps panning
    /// without a jump.
    func handle(_ e: PointerEvent) {
        let previous = lastPoint
        pointers.handle(e)
        pinch.handle(e, tracker: pointers)
        if e.phase == .moved, pointers.count >= 2 {
            let ids = Array(pointers.order.prefix(2))
            if let a0 = previous[ids[0]], let b0 = previous[ids[1]],
               let a1 = pointers.active[ids[0]], let b1 = pointers.active[ids[1]] {
                pinching = true
                let mid0 = (a0 + b0) / 2, mid1 = (a1 + b1) / 2
                let d0 = a0.distance(to: b0), d1 = a1.distance(to: b1)
                var v = state.viewport.panned(by: mid1 - mid0)
                if d0 > 0, d1 > 0 { v = v.pinched(by: d1 / d0, anchor: mid1) }
                apply(v)
            }
        } else if e.phase == .moved, pointers.count == 1, let last = previous[e.id] {
            apply(state.viewport.panned(by: e.location - last))
        }
        switch e.phase {
        case .began, .moved: lastPoint[e.id] = e.location
        case .ended, .cancelled: lastPoint[e.id] = nil
        }
        if pointers.count < 2 { pinching = false }
        if pointers.count == 0 { pinch.reset(); lastPoint.removeAll() }
    }

    /// Zoom in ×2 about the view's middle (the control alternative to pinching).
    func zoomIn() { apply(state.viewport.pinched(by: 2, anchor: state.viewport.size / 2)) }
    /// Zoom out ×0.5 about the view's middle.
    func zoomOut() { apply(state.viewport.pinched(by: 0.5, anchor: state.viewport.size / 2)) }
    /// Back to the mode's default framing at the current size.
    func resetView() {
        apply(PlaneViewport.framing(width: FractalState.defaultWidth(for: state.mode),
                                    center: FractalState.defaultCenter(for: state.mode), size: state.viewport.size))
    }

    /// True when the GPU picture is unavailable (no host, or the shader failed); the CPU preview is shown instead.
    var usingFallback: Bool { host == nil || scene.errorMessage != nil }

    /// The current mode's explanation.
    var explanation: String { FractalExplanations.text(for: state.mode) }

    /// The view's size changed (layout, rotation, split view): the viewport keeps its center and the span across the
    /// shorter side through VisualCore's `PlaneFraming` (feature 028 T-A03-306; FR-A03-306), so the zoom and the visible
    /// content stay the same with square pixels.
    func resize(to size: Vec2) {
        guard size.isFinite, size.x > 0, size.y > 0, size != state.viewport.size else { return }
        state.viewport = PlaneFraming(state.viewport).viewport(size: size)
    }

    /// Starts a CPU preview for the current state; a newer request supersedes it.
    func refresh() {
        requestID += 1
        let id = requestID, snapshot = state
        task = Task.detached(priority: .userInitiated) { [weak self] in
            let p = FractalPreview.render(snapshot, requestID: id)
            await self?.deliver(p)
        }
    }

    /// Accepts a preview only for the current request.
    func deliver(_ p: FractalPreview) {
        guard p.requestID == requestID else {
            droppedResults += 1
            return
        }
        preview = p
    }

    /// Waits for the latest preview (tests).
    func waitForPreview() async {
        while preview?.requestID != requestID { await Task.yield(); try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    /// Destroys the host (the screen went away).
    func close() {
        task?.cancel()
        host?.destroy()
        host = nil
    }

    /// The CPU preview as an image.
    var image: CGImage? {
        guard let p = preview else { return nil }
        let data = Data(p.rgba) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: p.width, height: p.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: p.width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

struct ExplorerView: View {
    @State private var model = ExplorerModel()
    @State private var showingBookmarks = false
    @State private var showingGoTo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Fractal", selection: $model.state.mode) {
                    ForEach(FractalMode.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fe.mode")
                Text(model.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("fe.mode.explanation")
                canvas
                HStack {
                    Button { model.zoomOut() } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                        .accessibilityIdentifier("fe.zoomOut")
                    Spacer()
                    Button { model.resetView() } label: { Label("Reset view", systemImage: "arrow.counterclockwise") }
                        .accessibilityIdentifier("fe.resetView")
                    Spacer()
                    Button { model.zoomIn() } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                        .accessibilityIdentifier("fe.zoomIn")
                }
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                if let text = model.notice.text {
                    Label(text, systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fe.precision")
                    Text(model.precisionSource)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fe.precision.source")
                }
                if let note = model.bookmarkNote {
                    Text(note)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fe.bookmark.note")
                }
                if model.usingFallback, let error = model.scene.errorMessage {
                    Text("The graphics shader could not run, so a simpler preview is shown. (\(error))")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fe.fallback")
                }
                Picker("Palette", selection: $model.paletteID) {
                    ForEach(ExplorerModel.paletteIDs, id: \.self) { id in
                        Text(Palette.builtIn(id)?.name ?? id).tag(id)
                    }
                }
                .accessibilityIdentifier("fe.palette")
                Toggle("Animate colors", isOn: $model.animate)
                    .accessibilityHint("Lets the palette flow along the bands")
                    .accessibilityIdentifier("fe.animate")
                if model.state.mode == .julia {
                    Text("Seed: \(FractalState.complex(model.state.juliaSeed))")
                        .accessibilityIdentifier("fe.seed")
                }
            }
            .padding()
        }
        .onDisappear { if !showingBookmarks { model.close() } }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingBookmarks = true } label: { Label("Bookmarks", systemImage: "bookmark") }
                    .accessibilityIdentifier("fe.bookmarks")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingGoTo = true } label: { Label("Go to coordinates", systemImage: "location.magnifyingglass") }
                    .accessibilityIdentifier("fe.goto")
            }
        }
        .sheet(isPresented: $showingBookmarks) { BookmarksView(model: model) }
        .sheet(isPresented: $showingGoTo) { GoToView(model: model) }
        .navigationTitle("Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AccessibleColors.accent)
    }

    private var canvas: some View {
        GeometryReader { geo in
            Group {
                if let host = model.host, !model.usingFallback {
                    RenderSurface(host: host, accessibilityLabel: model.canvasDescription,
                                  accessibilityHint: "Fractal picture. Pinch to zoom and drag to move; the zoom buttons do the same.")
                } else if let image = model.image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .accessibilityElement()
                        .accessibilityLabel(model.canvasDescription)
                        .accessibilityAddTraits(.isImage)
                } else {
                    Color.black
                }
            }
            .onAppear { model.resize(to: Vec2(Double(geo.size.width), Double(geo.size.height))) }
            .onChange(of: geo.size) { _, size in model.resize(to: Vec2(Double(size.width), Double(size.height))) }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fe.canvas")
    }
}
