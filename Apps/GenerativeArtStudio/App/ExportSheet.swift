// ExportSheet.swift — still export from the scene screen (feature 015 T-A01-405; FR-A01-401–FR-A01-407, FR-A01-409).
// Rendering, readback, PNG encoding and size math are VisualCore's (RenderHost.renderOffscreen, StillImageEncoder,
// ExportGeometry); this file holds only the app's flow: pause, scale point-sized content, write, share, clean up.
import Foundation
import GenerativeArtStudioCore
import Observation
import SwiftUI
import UIKit
import VisualCoreRendering
import VisualCoreScenes

/// Renders the scene model's composition to a PNG file and restores the live scene afterwards.
@MainActor
enum ExportRunner {
    /// Folder for export files (inside the app's temporary directory).
    static var directory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true) }

    /// The image for `options` at the clock's current time. Playback is paused for the export and restored after;
    /// point-sized content is scaled so it keeps its on-screen proportions (FR-A01-406).
    static func render(_ model: SceneModel, options: ExportOptions) throws -> StillImage {
        try render(model, size: options.size)
    }

    /// The image at an explicit pixel size (tests and previews use sizes outside the offered options).
    static func render(_ model: SceneModel, size: ExportSize) throws -> StillImage {
        guard let host = model.host else { throw OffscreenRenderError.unavailable("Rendering is unavailable.") }
        let wasPlaying = model.clocked.clock.isPlaying
        let liveScale = model.scene.displayScale
        model.clocked.clock.pause()
        defer {
            model.scene.displayScale = liveScale
            if wasPlaying { model.clocked.clock.play() }
            model.refresh()
        }
        model.scene.displayScale = exportScale(exportHeight: size.height, livePixelHeight: host.pixelSize.height,
                                               liveScale: liveScale)
        return try host.renderOffscreen(width: size.width, height: size.height, time: model.clocked.clock.time)
    }

    /// Points-to-pixels factor for an export: export height ÷ on-screen height in points (Clarifications).
    static func exportScale(exportHeight: Int, livePixelHeight: Int, liveScale: Double) -> Double {
        let scale = max(liveScale, 1)
        guard livePixelHeight > 0 else { return scale }
        let pointHeight = Double(livePixelHeight) / scale
        return Double(exportHeight) / pointHeight
    }

    /// Renders, encodes and writes `<name>-<w>x<h>.png`; returns the file URL.
    static func export(_ model: SceneModel, options: ExportOptions, name: String) throws -> URL {
        let png = try StillImageEncoder.pngData(render(model, options: options))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(options.fileName(for: name))
        try png.write(to: url, options: .atomic)
        return url
    }

    /// A readable message for an export failure.
    static func message(for error: Error) -> String {
        switch error {
        case OffscreenRenderError.invalidSize(let w, let h, let max):
            return "\(w) × \(h) px is larger than this device can render (up to \(max) px)."
        case OffscreenRenderError.resource:
            return "Not enough graphics memory for this size. Try a smaller size."
        case OffscreenRenderError.unavailable(let reason):
            return "Rendering is unavailable. \(reason)"
        case OffscreenRenderError.scene(let reason):
            return "The scene couldn’t be drawn: \(reason)"
        case OffscreenRenderError.readback, OffscreenRenderError.encoding:
            return "The image couldn’t be created."
        default:
            return "The file couldn’t be written: \(error.localizedDescription)"
        }
    }
}

/// Export sheet state: options, the crop preview, progress and the finished file.
@MainActor
@Observable
final class ExportModel: Identifiable {
    enum Phase: Equatable { case idle, rendering, ready(URL), failed(String) }

    let scene: SceneModel
    let name: String
    var options: ExportOptions { didSet { if options != oldValue { invalidate() } } }
    private(set) var phase: Phase = .idle
    private(set) var preview: UIImage?

    /// Long edge of the crop preview in pixels.
    static let previewEdge = 240

    init(scene: SceneModel, name: String) {
        self.scene = scene
        self.name = name
        options = ExportOptions(maxEdge: scene.host?.maxRenderSize ?? 0)
        options.longEdge = options.availableLongEdges.contains(2048) ? 2048 : options.availableLongEdges.last ?? 1080
        refreshPreview()
    }

    /// Re-renders the small crop preview for the chosen aspect.
    func refreshPreview() {
        var small = options
        small.longEdge = Self.previewEdge
        guard let image = try? ExportRunner.render(scene, options: small),
              let png = try? StillImageEncoder.pngData(image) else { preview = nil; return }
        preview = UIImage(data: png)
    }

    /// Runs the export after the progress indicator has been shown.
    func run() async {
        removeFile()
        phase = .rendering
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))   // let the progress indicator draw before the main thread works
        do { phase = .ready(try ExportRunner.export(scene, options: options, name: name)) }
        catch { phase = .failed(ExportRunner.message(for: error)) }
    }

    /// Deletes the finished file (sheet closed or options changed).
    func removeFile() {
        if case .ready(let url) = phase { try? FileManager.default.removeItem(at: url) }
    }

    private func invalidate() {
        removeFile()
        phase = .idle
        refreshPreview()
    }
}

struct ExportSheet: View {
    @State var model: ExportModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
                Section("Size") {
                    Picker("Size", selection: $model.options.longEdge) {
                        ForEach(model.options.availableLongEdges, id: \.self) { edge in
                            Text(verbatim: "\(edge) px").tag(edge)
                        }
                    }
                    .accessibilityIdentifier("gas.export.size")
                    .accessibilityValue(Text(verbatim: "\(model.options.longEdge) px"))
                    Picker("Aspect", selection: $model.options.aspect) {
                        ForEach(ExportAspect.builtIns) { aspect in Text(aspect.title).tag(aspect) }
                    }
                    .accessibilityIdentifier("gas.export.aspect")
                    .accessibilityValue(Text(model.options.aspect.title))
                    LabeledContent("Dimensions") {
                        Text(verbatim: model.options.dimensionsLabel).accessibilityIdentifier("gas.export.dimensions")
                    }
                    LabeledContent("Format") {
                        Text(verbatim: ExportOptions.formatLabel).accessibilityIdentifier("gas.export.format")
                    }
                }
                Section { action }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("gas.export.done")
                }
            }
            .disabled(model.phase == .rendering)
        }
        .accessibilityIdentifier("gas.export.sheet")
        .onDisappear { model.removeFile() }
    }

    @ViewBuilder private var preview: some View {
        let aspect = model.options.aspect
        Group {
            if let image = model.preview {
                Image(uiImage: image).resizable().interpolation(.medium)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(CGFloat(aspect.width) / CGFloat(aspect.height), contentMode: .fit)
        .frame(maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Crop preview, \(aspect.title)")
        .accessibilityIdentifier("gas.export.preview")
    }

    @ViewBuilder private var action: some View {
        switch model.phase {
        case .idle:
            Button("Export Image") { Task { await model.run() } }
                .accessibilityIdentifier("gas.export.run")
        case .rendering:
            HStack(spacing: 12) {
                ProgressView()
                Text("Rendering \(model.options.dimensionsLabel)…")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("gas.export.progress")
        case .ready(let url):
            ShareLink(item: url) { Label("Share or Save Image", systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("gas.export.share")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).foregroundStyle(.red).accessibilityIdentifier("gas.export.error")
                Button("Try Again") { Task { await model.run() } }.accessibilityIdentifier("gas.export.run")
            }
        }
    }
}
