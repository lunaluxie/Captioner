import SwiftUI
import UniformTypeIdentifiers

/// One video: the live preview on top, the editable caption list below, and the tools in the
/// bottom bar. The style, position and caption settings open as sheets.
struct EditorView: View {
    @Bindable var item: CaptionItem
    @Environment(CaptionQueue.self) private var queue
    @Environment(AppState.self) private var appState
    @State private var showStyle = false
    @State private var showPosition = false
    @State private var showCaptionSettings = false
    @State private var exportResult: URL?
    @State private var exportNote = ""
    @State private var confirmRegenerate = false

    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                MobileStatusBanner(item: item)
                MobilePreviewView(item: item)
                    .frame(height: previewHeight(for: geometry.size))
                Divider()
                CaptionListView(item: item)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { showStyle = true } label: { Label("Style", systemImage: "textformat") }
                Button { showPosition = true } label: { Label("Position", systemImage: "rectangle.bottomthird.inset.filled") }
                Button { showCaptionSettings = true } label: { Label("Captions", systemImage: "captions.bubble") }
                Spacer()
                Button {
                    queue.export([item.id])
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!item.hasCaptions || item.status.isBusy)
            }
        }
        .sheet(isPresented: $showStyle) { StyleSheet(item: item) }
        .sheet(isPresented: $showPosition) { PositionSheet(item: item) }
        .sheet(isPresented: $showCaptionSettings) { CaptionsSheet(item: item) }
        .task(id: "\(item.id)-\(item.info == nil)") {
            let player = appState.player
            player.load(asset: item.asset, makeComposition: { item.makeComposition() }, duration: item.duration)
            item.onRenderChange = { player.refreshFrame() }
        }
        .onDisappear {
            appState.player.pause()
            item.onRenderChange = nil
        }
        .onChange(of: item.status) { old, new in
            if new == .exported, old == .exporting, let url = item.exportedURL {
                finishExport(url)
            }
        }
        .alert("Exported", isPresented: Binding(get: { exportResult != nil }, set: { if !$0 { exportResult = nil } })) {
            if let url = exportResult {
                ShareLink(item: url) { Text("Share…") }
            }
            Button("Done") { exportResult = nil }
        } message: {
            Text(exportNote)
        }
    }

    /// Portrait videos get more of the screen than wide ones, and the list always keeps some room.
    private func previewHeight(for size: CGSize) -> CGFloat {
        let aspect = item.renderSize.height / max(item.renderSize.width, 1)
        let natural = size.width * aspect + 44
        return min(max(natural, 220), size.height * 0.58)
    }

    private func finishExport(_ url: URL) {
        guard settings.saveToPhotos else {
            exportNote = "\(url.lastPathComponent) is in Captioner's folder in the Files app."
            exportResult = url
            return
        }
        Task {
            do {
                try await MediaImporter.saveToPhotos(url)
                exportNote = "\(url.lastPathComponent) was added to your Photos library and kept in Captioner's folder in Files."
            } catch {
                exportNote = "\(url.lastPathComponent) is in Captioner's folder in the Files app. It couldn't be added to Photos: \(error.localizedDescription)"
            }
            exportResult = url
        }
    }
}

/// A slim bar above the preview showing what is happening to the video.
struct MobileStatusBanner: View {
    let item: CaptionItem
    @Environment(CaptionQueue.self) private var queue

    var body: some View {
        Group {
            switch item.status {
            case .loading:
                row(icon: "clock", text: "Reading video…", progress: nil)
            case .waiting:
                row(icon: "clock", text: "Waiting to generate captions…", progress: nil)
            case .transcribing:
                if let job = item.job {
                    row(icon: "waveform", text: job.phase == .downloading ? job.status : (job.liveText.isEmpty ? job.status : job.liveText),
                        progress: job.phase == .downloading ? job.downloadProgress : job.progress)
                }
            case .exporting:
                row(icon: "square.and.arrow.up", text: "Exporting…", progress: item.exportProgress)
            case .failed(let message):
                row(icon: "exclamationmark.triangle.fill", text: message, progress: nil)
            case .ready, .exported:
                if item.isTranslating {
                    row(icon: "globe", text: "Translating…", progress: nil)
                }
            }
        }
        .animation(.default, value: item.status)
    }

    private func row(icon: String, text: String, progress: Double?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(.secondary)
                Spacer()
                if let progress {
                    Text("\(Int(progress * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            if let progress {
                ProgressView(value: progress)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
}
